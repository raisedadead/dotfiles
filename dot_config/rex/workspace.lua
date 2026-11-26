local lib = require("lib")

local then_shell = lib.then_shell

local function shell(cwd)
  return rex.layout.block{ flavor = lib.SHELL, options = { cwd = cwd } }
end

local LAYOUTS = {
  agent = function(cwd)
    return rex.layout.horizontal(0.6, then_shell(lib.AGENT, cwd, "agent"), shell(cwd))
  end,
  dev = function(cwd)
    return rex.layout.horizontal(0.6, then_shell(lib.EDITOR, cwd, "editor"),
      then_shell(lib.AGENT, cwd, "agent"))
  end,
}

local function focused_cwd(ctx)
  local src = lib.source(ctx)
  if not src then return nil end
  local _, cwd = lib.fg(ctx.session_id, src)
  return cwd
end

for name, make in pairs(LAYOUTS) do
  rex.action{
    name = "layout_" .. name, title = "Layout: " .. name, category = "Layouts",
    args = { cwd = "string?" },
    run = function(ctx, args)
      local w, err = rex.session.new_window{
        window_label = name,
        layout = make(args.cwd or focused_cwd(ctx)),
      }
      if not w then error(err, 0) end
      return { window_id = w.window_id }
    end,
  }
end

local STATE = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state"))
  .. "/rex/"
local MAP = STATE .. "workspaces.json"
local MAX_LABEL = 128

local function realdir(path)
  local r = rex.exec({ "/bin/pwd", "-P" }, { cwd = path })
  if not (r and r.ok) then return nil end
  return (r.stdout:gsub("\n$", ""))
end

local function sessions()
  local l, err = rex.call("session.list", {})
  if not l then error(err, 0) end
  local labels = {}
  for _, s in ipairs(l.sessions or {}) do labels[s.session_id] = s.label or "" end
  return l.sessions or {}, labels
end

local function load_map(labels)
  local m = {}
  local f = io.open(MAP)
  if not f then return m end
  local ok, saved = pcall(rex.json.decode, f:read("*a"))
  f:close()
  if not ok or type(saved) ~= "table" then return m end
  for path, sid in pairs(saved) do
    if type(path) == "string" and labels[sid] then m[path] = sid end
  end
  return m
end

local function save_map(m)
  rex.exec({ "mkdir", "-p", STATE })
  local f, err = io.open(MAP .. ".tmp", "w")
  if not f then return rex.log("warn", "workspace map not saved: " .. tostring(err)) end
  f:write(rex.json.encode(m))
  f:close()
  os.rename(MAP .. ".tmp", MAP)
end

local function runs_in(sid, real)
  local r = rex.session.list_blocks{ session_id = sid }
  for _, b in ipairs(r and r.blocks or {}) do
    local _, cwd = lib.fg(sid, b.block_id)
    if cwd and realdir(cwd) == real then return true end
  end
  return false
end

local function fit(base, suffix)
  local room = MAX_LABEL - #suffix
  if #base > room then
    base = base:sub(1, room):gsub("[\192-\255][\128-\191]*$", "")
  end
  return base .. suffix
end

local function free_label(name, real, taken)
  local parent = real:match("([^/]+)/[^/]+$") or "/"
  local label, n = fit(name, ""), 1
  while taken[label] do
    label = fit(name, " (" .. parent .. (n > 1 and " " .. n or "") .. ")")
    n = n + 1
  end
  return label
end

local function open(path, name)
  local real = realdir(path)
  if not real then error("no such directory: " .. path, 0) end
  local list, labels = sessions()
  local map = load_map(labels)
  local sid = map[real]
  if not sid then
    for _, s in ipairs(list) do
      if s.label == name and runs_in(s.session_id, real) then
        sid = s.session_id
        break
      end
    end
  end
  local created = false
  if not sid then
    local taken = {}
    for _, label in pairs(labels) do taken[label] = true end
    local label = free_label(name, real, taken)
    local s, err = rex.call("session.create", {
      label = label,
      initial_windows = { { window_label = "agent", layout = LAYOUTS.agent(real) } },
    })
    if not s then error(err, 0) end
    sid, created, labels[s.session_id] = s.session_id, true, label
  end
  if map[real] ~= sid then
    map[real] = sid
    save_map(map)
  end
  return { session_id = sid, created = created, label = labels[sid] }
end

rex.action{
  name = "workspace_open", title = "Open Workspace", category = "Layouts",
  args = { path = "string", name = "string" },
  run = function(_, args) return open(args.path, args.name) end,
}

rex.action{
  name = "workspace_known", title = "Workspace Sessions", category = "Layouts",
  run = function()
    local _, labels = sessions()
    return { paths = load_map(labels) }
  end,
}

return { open = open }
