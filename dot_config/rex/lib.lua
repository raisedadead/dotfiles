local M = {}

M.TERMINAL = "com.superlogical.terminal"
M.SHELL = M.TERMINAL .. ".shell"
M.AGENTS = { claude = true, codex = true, pi = true, opencode = true }
M.AGENT = os.getenv("REX_TEST_AGENT") or "claude"
M.PI = os.getenv("REX_TEST_PI") or "pi"
M.EDITOR = os.getenv("REX_TEST_EDITOR") or "nvim"

local here = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
M.DIR = here:match("^@?(/.*)/[^/]*$") or (os.getenv("HOME") .. "/.config/rex")
M.BIN = M.DIR .. "/bin/"

function M.bcall(sid, bid, method, args)
  return rex.call("block.method", {
    session_id = sid, block_id = bid, method = method, args = args or {},
  })
end

function M.where(sid, window_id)
  local v, err = rex.session.view{ session_id = sid }
  if not v then return nil, err end
  local wid = window_id or v.active_window_id
  for _, w in ipairs(v.windows or {}) do
    if w.window_id == wid then
      local here = {
        window_id = w.window_id, focused = w.focused_block_id,
        zoomed = w.zoomed_block_id, labels = {}, floating = {},
      }
      for _, l in ipairs(w.layers or {}) do
        for _, b in ipairs(l.blocks or {}) do
          here.labels[b.block_id] = b.label
          if l.kind ~= "tiled" then here.floating[b.block_id] = l end
          if l.kind == "tiled" and not here.anchor then here.anchor = b.block_id end
        end
      end
      return here
    end
  end
  return nil, "no active window in " .. tostring(sid)
end

function M.find_label(sid, label)
  local r, err = rex.session.list_blocks{ session_id = sid }
  if not r then return nil, err end
  for _, b in ipairs(r.blocks) do
    if b.label == label then return b end
  end
end

local function base(s)
  if not s then return nil end
  local name = s:match("([^/]+)$") or s
  return (name:gsub("%.[cm]?js$", ""))
end

function M.fg(sid, bid)
  local p, err = M.bcall(sid, bid, "process")
  if not p then return nil, nil, err end
  local f = p.foreground
  if not f then return nil, nil, "no foreground program in " .. bid end
  return f, f.cwd
end

function M.runs(f, names)
  for _, k in ipairs({ "script", "argv0", "name", "path", "invoked_path" }) do
    local n = base(f[k])
    if n and names[n] then return n end
  end
end

function M.agent_in(f)
  return M.runs(f, M.AGENTS)
end

function M.safe_write(sid, bid, text)
  local f, _, err = M.fg(sid, bid)
  if not f then return nil, "refused: " .. tostring(err) end
  local agent = M.agent_in(f)
  if agent then
    return nil, "refused: " .. agent .. " runs in " .. bid
  end
  local m = M.bcall(sid, bid, "input_mode")
  if not m then return nil, "refused: no input mode for " .. bid end
  if m.echo == false and m.canonical == true then
    return nil, "refused: " .. bid .. " reads a password"
  end
  return M.bcall(sid, bid, "write", { data = text })
end

-- A key action writes to the pane the operator chose; it skips the safe_write checks.
function M.unchecked_write(sid, bid, data)
  return M.bcall(sid, bid, "write", { data = data })
end

local SH = os.getenv("SHELL") or "/bin/zsh"

function M.then_shell(cmd, cwd, label)
  return rex.layout.block{
    flavor = M.SHELL, label = label,
    options = { command = { SH, "-ic", cmd .. "; exec " .. SH .. " -i" }, cwd = cwd },
  }
end

function M.window_of(sid, bid)
  local v = rex.session.view{ session_id = sid }
  for _, w in ipairs(v and v.windows or {}) do
    for _, l in ipairs(w.layers) do
      for _, b in ipairs(l.blocks) do
        if b.block_id == bid then return w.window_id, l.kind end
      end
    end
  end
end

local function runs_agent(argv)
  for _, a in ipairs(argv) do
    local n = base(a)
    if M.AGENTS[n] or n == base(M.AGENT) then return true end
  end
  return false
end

-- The popup state lives in the rex-popup argv, so it survives a config reload.
function M.popup_of(sid, bid)
  local p = M.bcall(sid, bid, "process")
  local c = p and p.child
  if not (c and c.pid and c.name == "bash") then return nil end
  local r = rex.exec({ "/bin/ps", "-ww", "-o", "args=", "-p", tostring(c.pid) })
  if not (r and r.ok) then return nil end
  local w = {}
  for t in r.stdout:gmatch("%S+") do w[#w + 1] = t end
  local i = 1
  while w[i] and base(w[i]) ~= "rex-popup" do i = i + 1 end
  if w[i + 4] ~= "--" then return nil end
  local function id(s) if s ~= "-" then return s end end
  return {
    src = id(w[i + 1]), ret = id(w[i + 2]), zoomed = id(w[i + 3]),
    agent = runs_agent({ unpack(w, i + 5) }),
  }
end

function M.source(ctx, here)
  local bid = ctx.block_id
  if not bid then
    here = here or M.where(ctx.session_id)
    bid = here and here.focused
  end
  local p = bid and M.popup_of(ctx.session_id, bid)
  return p and p.src or bid
end

local function close(sid, bid, p, inside)
  local _, err = rex.call("block.close", { session_id = sid, block_id = bid })
  if err then return nil, err end
  if not inside then return true end
  if p.ret then rex.session.focus_block{ session_id = sid, block_id = p.ret } end
  if p.zoomed then
    rex.session.zoom_block{ session_id = sid, block_id = p.zoomed, zoom = true }
  end
  return true
end

function M.close_popup(ctx, bid)
  local sid = ctx.session_id
  local p = M.popup_of(sid, bid)
  local here = M.where(sid, M.window_of(sid, bid))
  if not (p and here and (here.labels[bid] or ""):match("^popup:")) then return false end
  if p.agent then return false, nil, p end
  return close(sid, bid, p, (ctx.block_id or here.focused) == bid)
end

local SHELLS = { zsh = true, bash = true, sh = true, fish = true }

-- A shell line editor turns canonical mode off; a script that reads a line keeps it on.
function M.at_prompt(sid, bid)
  local f = M.fg(sid, bid)
  if not (f and M.runs(f, SHELLS)) then return false end
  local m = M.bcall(sid, bid, "input_mode")
  return m ~= nil and m.canonical == false
end

-- Rex restores a block without its command, so a restored block runs a login shell.
function M.restored(sid, bid)
  local p = M.bcall(sid, bid, "process")
  return p ~= nil and p.child ~= nil and p.child.name == "login"
end

function M.orphan(sid, bid)
  return M.restored(sid, bid) and M.at_prompt(sid, bid)
end

-- An agent popup is never closed by its key: that would end the agent's session.
local function reuse(ctx, here, bid)
  local sid = ctx.session_id
  local p = (ctx.block_id or here.focused) == bid and M.popup_of(sid, bid)
  if not p or p.agent then
    rex.session.focus_block{ session_id = sid, block_id = bid }
    return bid, nil, "focused"
  end
  local ok, err = close(sid, bid, p, true)
  if not ok then return nil, err end
  return bid, nil, "closed"
end

function M.popup(ctx, o)
  local sid = ctx.session_id
  local here, err = M.where(sid, o.window_id)
  if not here then return nil, err end
  local old
  for bid, label in pairs(here.labels) do
    if o.label and o.label:match("^popup:") and label == o.label then old = bid end
  end
  if old and not M.orphan(sid, old) then return reuse(ctx, here, old) end
  if old then
    local _, cerr = rex.call("block.close", { session_id = sid, block_id = old })
    if cerr then return nil, cerr end
    if ctx.block_id == old then ctx = { session_id = sid } end
    here, err = M.where(sid, o.window_id)
    if not here then return nil, err end
  end
  local src = M.source(ctx, here)
  local cwd = o.cwd
  if not cwd and src then
    local _, c = M.fg(sid, src)
    cwd = c
  end
  local cmd = {
    M.BIN .. "rex-popup", src or "-", here.focused or "-", here.zoomed or "-", "--",
  }
  for _, a in ipairs(o.cmd) do cmd[#cmd + 1] = a end
  local r, e = rex.session.new_layer{
    session_id = sid, window_id = here.window_id, focus = true,
    bounds = o.bounds or { 0.1, 0.1, 0.8, 0.8 },
    layout = rex.layout.block{
      flavor = M.SHELL, label = o.label,
      options = { command = cmd, cwd = cwd },
    },
  }
  if not r then return nil, e end
  return r.block_ids[1]
end

return M
