local lib = require("lib")

local SH = os.getenv("SHELL") or "/bin/zsh"

local function then_shell(cmd, cwd, label)
  return rex.layout.block{
    flavor = lib.SHELL, label = label,
    options = { command = { SH, "-ic", cmd .. "; exec " .. SH .. " -i" }, cwd = cwd },
  }
end

local function shell(cwd)
  return rex.layout.block{ flavor = lib.SHELL, options = { cwd = cwd } }
end

local LAYOUTS = {
  agent = function(cwd, agent)
    return rex.layout.horizontal(0.6, then_shell(agent, cwd, "agent"), shell(cwd))
  end,
  dev = function(cwd, agent)
    return rex.layout.horizontal(0.6, then_shell("nvim", cwd, "editor"),
      then_shell(agent, cwd, "agent"))
  end,
}

local function focused_cwd(ctx)
  local here = lib.where(ctx.session_id)
  local src = ctx.block_id or (here and here.focused)
  if not src then return nil end
  local _, cwd = lib.fg(ctx.session_id, src)
  return cwd
end

for name, make in pairs(LAYOUTS) do
  rex.action{
    name = "layout_" .. name, title = "Layout: " .. name, category = "Layouts",
    args = { cwd = "string?", agent = "string?" },
    run = function(ctx, args)
      local w, err = rex.session.new_window{
        window_label = name,
        layout = make(args.cwd or focused_cwd(ctx), args.agent or "claude"),
      }
      if not w then error(err, 0) end
      return { window_id = w.window_id }
    end,
  }
end

rex.action{
  name = "workspace_open", title = "Open Workspace", category = "Layouts",
  args = { path = "string", name = "string", agent = "string?" },
  run = function(_, args)
    local l, err = rex.call("session.list", {})
    if not l then error(err, 0) end
    for _, s in ipairs(l.sessions or {}) do
      if s.label == args.name then
        return { session_id = s.session_id, created = false }
      end
    end
    local layout = LAYOUTS.agent(args.path, args.agent or "claude")
    local s, cerr = rex.call("session.create", {
      label = args.name,
      initial_windows = { { window_label = "agent", layout = layout } },
    })
    if not s then error(cerr, 0) end
    return { session_id = s.session_id, created = true }
  end,
}

rex.action{
  name = "popup_workspace", title = "Workspaces", category = "Popups",
  run = function(ctx)
    local b, err = lib.popup(ctx, {
      label = "popup:workspace", bounds = { 0.2, 0.15, 0.6, 0.7 },
      cmd = { lib.BIN .. "rex-pick-workspace", ctx.client_id or "", focused_cwd(ctx) or "" },
    })
    if not b then error(err, 0) end
    return { block_id = b }
  end,
}
