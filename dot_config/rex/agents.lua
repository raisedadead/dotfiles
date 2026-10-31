local lib = require("lib")

local RANK = { blocked = 1, error = 2, done = 3 }

local function waiting(skip)
  local l, err = rex.call("session.list", {})
  if not l then return nil, err end
  local best
  for _, s in ipairs(l.sessions or {}) do
    local bl = rex.call("session.list_blocks", { session_id = s.session_id })
    for _, b in ipairs(bl and bl.blocks or {}) do
      if b.block_id ~= skip then
        local ps = lib.bcall(s.session_id, b.block_id, "program_status")
        for _, r in ipairs(ps and ps.records or {}) do
          local rank = RANK[r.state]
          if rank and (not best or rank < best.rank
              or (rank == best.rank and (r.updated_at or "") < best.at)) then
            best = {
              rank = rank, at = r.updated_at or "", state = r.state,
              session_id = s.session_id, block_id = b.block_id,
            }
          end
        end
      end
    end
  end
  return best
end

rex.action{
  name = "next_waiting", title = "Next Waiting Agent", category = "Agents",
  run = function(ctx)
    local w, err = waiting(ctx.block_id)
    if err then error(err, 0) end
    if not w then return { state = "none" } end
    local _, ferr = rex.session.focus_block{ session_id = w.session_id, block_id = w.block_id }
    if ferr then error(ferr, 0) end
    if w.session_id ~= ctx.session_id then
      rex.client.queue("session.select", { session_id = w.session_id })
    end
    return { state = w.state, session_id = w.session_id, block_id = w.block_id }
  end,
}

local function cwd_of(ctx)
  local src = ctx.block_id
  if not src then
    local here = lib.where(ctx.session_id)
    src = here and here.focused
  end
  if not src then return nil, nil end
  local _, cwd = lib.fg(ctx.session_id, src)
  return src, cwd
end

rex.action{
  name = "agent_here", title = "Agent Here", category = "Agents",
  args = { agent = "string?" },
  run = function(ctx, args)
    local src, cwd = cwd_of(ctx)
    if not src then error("no pane to split", 0) end
    local r, err = rex.call("session.new_split", {
      session_id = ctx.session_id, anchor_id = src, direction = "horizontal",
      side = "after", focus = true,
      layout = lib.then_shell(args.agent or "claude", cwd, "agent"),
    })
    if not r then error(err, 0) end
    return { block_id = r.block_ids[1] }
  end,
}

rex.action{
  name = "ask_pane", title = "Ask About This Pane", category = "Agents",
  args = { agent = "string?" },
  run = function(ctx, args)
    local src, cwd = cwd_of(ctx)
    if not src then error("no pane to ask about", 0) end
    local b, err = lib.popup(ctx, {
      label = "popup:ask", cwd = cwd,
      cmd = { lib.BIN .. "rex-ask", src, args.agent or "claude" },
    })
    if not b then error(err, 0) end
    return { block_id = b }
  end,
}
