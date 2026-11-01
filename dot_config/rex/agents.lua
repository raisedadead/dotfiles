local lib = require("lib")

local RANK = { blocked = 1, error = 2, done = 3 }

local function best_record(sid, b)
  local ps = lib.bcall(sid, b.block_id, "program_status")
  local best, agent
  for _, r in ipairs(ps and ps.records or {}) do
    local rank = RANK[r.state]
    if rank and r.app ~= "handoff" then
      if agent == nil then agent = lib.agent_in(lib.fg(sid, b.block_id) or {}) ~= nil end
      if not agent then rank = nil end
    end
    local at = r.updated_at or ""
    if rank and (not best or rank < best.rank or (rank == best.rank and at < best.at)) then
      best = { rank = rank, at = at, state = r.state, session_id = sid, block_id = b.block_id }
    end
  end
  return best
end

local function before(a, b)
  if a.rank ~= b.rank then return a.rank < b.rank end
  if a.at ~= b.at then return a.at < b.at end
  return a.block_id < b.block_id
end

local function sessions()
  local a, err = rex.call("session.attach_all", { event_scope = "session" })
  if not a then return nil, err end
  return a.sessions or {}
end

local function waiting()
  local all, err = sessions()
  if not all then return nil, err end
  local list = {}
  for _, s in ipairs(all) do
    local bl = rex.call("session.list_blocks", { session_id = s.session_id })
    for _, b in ipairs(bl and bl.blocks or {}) do
      local w = b.placement ~= "detached" and best_record(s.session_id, b)
      if w then list[#list + 1] = w end
    end
  end
  table.sort(list, before)
  return list
end

rex.action{
  name = "next_waiting", title = "Next Waiting Agent", category = "Agents",
  run = function(ctx)
    local list, err = waiting()
    if not list then error(err, 0) end
    local i = 0
    for k, w in ipairs(list) do
      if w.block_id == ctx.block_id then i = k end
    end
    local w = #list > 0 and list[i % #list + 1]
    if not w or w.block_id == ctx.block_id then error("no other agent is waiting", 0) end
    local _, ferr = rex.session.focus_block{ session_id = w.session_id, block_id = w.block_id }
    if ferr then error(ferr, 0) end
    if w.session_id ~= ctx.session_id then
      rex.client.queue("session.select", { session_id = w.session_id })
    end
    return { state = w.state, session_id = w.session_id, block_id = w.block_id }
  end,
}

local function cwd_of(ctx)
  local src = lib.source(ctx)
  if not src then return nil, nil end
  local _, cwd = lib.fg(ctx.session_id, src)
  return src, cwd
end

rex.action{
  name = "agent_here", title = "Agent Here", category = "Agents",
  run = function(ctx)
    local sid = ctx.session_id
    local src, cwd = cwd_of(ctx)
    if not src then error("no pane to split", 0) end
    local anchor, drawer, wid, kind = src, false, lib.window_of(sid, src)
    if kind and kind ~= "tiled" then
      local here = lib.where(sid, wid)
      anchor = here and here.anchor
      if not anchor then error("this tab has no tiled pane to split", 0) end
      drawer = here.labels[src] == "drawer:scratch"
    end
    local self = ctx.block_id
    if not self then
      local here = lib.where(sid)
      self = here and here.focused
    end
    local at = self and lib.where(sid, lib.window_of(sid, self))
    local popup = at and (at.labels[self] or ""):match("^popup:") and self
    if popup then
      local p = lib.popup_of(sid, self)
      if not p or p.agent then popup = nil end
    end
    local r, err = rex.call("session.new_split", {
      session_id = sid, anchor_id = anchor, direction = "horizontal",
      side = "after", focus = true,
      layout = lib.then_shell(lib.AGENT, cwd, "agent"),
    })
    if not r then error(err, 0) end
    local bid = r.block_ids[1]
    if drawer then
      rex.session.detach_block{ session_id = sid, block_id = src }
    end
    if popup then rex.call("block.close", { session_id = sid, block_id = popup }) end
    if drawer or popup then rex.session.focus_block{ session_id = sid, block_id = bid } end
    return { block_id = bid }
  end,
}

local STATE = (os.getenv("REX_AGENT_DIR")
  or (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/rex/agents")
  .. "/"

local H = "%x%x%x%x"
local UUID = "^" .. H .. H .. "%-" .. H .. "%-" .. H .. "%-" .. H .. "%-" .. H .. H .. H .. "$"

local function record(bid)
  local path = STATE .. bid:gsub("^block:", "") .. ".json"
  local f = io.open(path)
  if not f then return nil end
  local text = f:read("*a")
  f:close()
  local ok, r = pcall(rex.json.decode, text)
  if not ok or type(r) ~= "table" or r.block ~= bid or r.agent ~= "claude" then return nil end
  if type(r.session_id) ~= "string" or not r.session_id:match(UUID) then return nil end
  return r, path
end

local at_prompt, restored = lib.at_prompt, lib.restored

local function reap(sid, bid)
  local wid = lib.window_of(sid, bid)
  local before = wid and lib.where(sid, wid)
  local _, err = rex.call("block.close", { session_id = sid, block_id = bid })
  if err then return false end
  if before and before.focused == bid and before.anchor then
    rex.session.focus_block{ session_id = sid, block_id = before.anchor }
  end
  return true
end

local RELAUNCH = { editor = lib.EDITOR }

rex.action{
  name = "agents_resume", title = "Resume After Restart", category = "Agents",
  run = function()
    local all, err = sessions()
    if not all then error(err, 0) end
    local resumed, closed, relaunched = {}, {}, {}
    for _, s in ipairs(all) do
      local sid = s.session_id
      local bl = rex.call("session.list_blocks", { session_id = sid })
      for _, b in ipairs(bl and bl.blocks or {}) do
        local bid, label = b.block_id, b.label or ""
        local r, path = record(bid)
        local float = label:match("^popup:") or label == "handoff"
        if float then
          if restored(sid, bid) and at_prompt(sid, bid) then
            if reap(sid, bid) then
              if path then os.remove(path) end
              closed[#closed + 1] = bid
            end
          end
        elseif r and at_prompt(sid, bid) then
          local _, werr = lib.safe_write(sid, bid,
            r.agent .. " --resume " .. r.session_id .. "\n")
          if not werr then
            os.remove(path)
            resumed[#resumed + 1] = bid
          end
        elseif RELAUNCH[label] and restored(sid, bid) and at_prompt(sid, bid) then
          local _, werr = lib.safe_write(sid, bid, RELAUNCH[label] .. "\n")
          if not werr then relaunched[#relaunched + 1] = bid end
        end
      end
    end
    return { resumed = resumed, count = #resumed, closed = closed, relaunched = relaunched }
  end,
}

rex.action{
  name = "ask_pane", title = "Ask About This Pane", category = "Agents",
  run = function(ctx)
    local src, cwd = cwd_of(ctx)
    if not src then error("no pane to ask about", 0) end
    local b, err = lib.popup(ctx, {
      label = "popup:ask", cwd = cwd,
      cmd = { lib.BIN .. "rex-ask", src, lib.AGENT },
    })
    if not b then error(err, 0) end
    return { block_id = b }
  end,
}
