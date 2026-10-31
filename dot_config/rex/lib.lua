local M = {}

M.TERMINAL = "com.superlogical.terminal"
M.SHELL = M.TERMINAL .. ".shell"
M.AGENTS = { claude = true, codex = true, pi = true, opencode = true }
M.AGENT = os.getenv("REX_TEST_AGENT") or "claude"

local here = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
M.DIR = here:match("^@?(/.*)/[^/]*$") or (os.getenv("HOME") .. "/.config/rex")
M.BIN = M.DIR .. "/bin/"

function M.bcall(sid, bid, method, args)
  return rex.call("block.method", {
    session_id = sid, block_id = bid, method = method, args = args or {},
  })
end

function M.where(sid)
  local v, err = rex.session.view{ session_id = sid }
  if not v then return nil, err end
  for _, w in ipairs(v.windows) do
    if w.window_id == v.active_window_id then
      local anchor
      for _, l in ipairs(w.layers) do
        if not anchor and l.kind == "tiled" and l.blocks[1] then
          anchor = l.blocks[1].block_id
        end
      end
      return {
        window_id = w.window_id, focused = w.focused_block_id, anchor = anchor,
      }
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
        if b.block_id == bid then return w.window_id end
      end
    end
  end
end

function M.popup(ctx, o)
  local sid = ctx.session_id
  local here, err = M.where(sid)
  if not here then return nil, err end
  local src = ctx.block_id or here.focused
  local cwd = o.cwd
  if not cwd and src then
    local _, c = M.fg(sid, src)
    cwd = c
  end
  local r, e = rex.session.new_layer{
    session_id = sid, window_id = o.window_id or here.window_id, focus = true,
    bounds = o.bounds or { 0.1, 0.1, 0.8, 0.8 },
    layout = rex.layout.block{
      flavor = M.SHELL, label = o.label,
      options = { command = o.cmd, cwd = cwd, shell = not o.login and "none" or nil },
    },
  }
  if not r then return nil, e end
  return r.block_ids[1]
end

return M
