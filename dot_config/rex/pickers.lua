local lib = require("lib")
local side = require("side")
local workspace = require("workspace")

local M = {}

local MAX = 2000
local BOOKMARKS = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state"))
  .. "/switcher/bookmarks"
local MD_GLOBS = { "*.md", "*.markdown", "*.mdown", "*.mkd", "*.mkdn", "*.mdwn", "*.mdtext", "*.mdx" }
local WALK = { "--glob", "!.git", "--glob", "!node_modules", "--glob", "!.venv", "--glob", "!.claude" }
local LOOSE = {
  "--max-depth", "6", "--glob", "!/Library", "--glob", "!/.Trash", "--glob", "!/.cache",
  "--glob", "!.scratchpad",
}

local function fail(err) error(err, 0) end

local function out(argv, cwd)
  local r = lib.run(argv, cwd)
  if r and r.ok then return r.stdout end
end

local function chomp(s)
  return s and (s:gsub("%s+$", "")) or nil
end

local function lines(s)
  return (s or ""):gmatch("[^\n]+")
end

local function basename(p)
  return p:match("([^/]+)/*$") or p
end

local function append(t, more)
  for _, v in ipairs(more) do t[#t + 1] = v end
  return t
end

local function rows()
  local list, seen = {}, {}
  local function add(row)
    if #list >= MAX or seen[row.id] then return end
    seen[row.id] = true
    list[#list + 1] = row
  end
  return list, add
end

local function cwd_of(ctx)
  local src = lib.source(ctx)
  if not src then return nil end
  local _, cwd = lib.fg(ctx.session_id, src)
  return cwd
end

local function git_root(cwd)
  return cwd and chomp(out({ "git", "-C", cwd, "rev-parse", "--show-toplevel" }))
end

local function worktrees(root)
  local ok, j = pcall(rex.json.decode, out({ "wt", "-C", root, "list", "--format", "json" }) or "")
  if not ok or type(j) ~= "table" then return {} end
  return j.items or {}
end

local function bookmarks()
  local list = {}
  local f = io.open(BOOKMARKS)
  if not f then return list end
  for line in f:lines() do
    if line ~= "" then list[#list + 1] = line end
  end
  f:close()
  return list
end

function M.switch_rows(ctx)
  local list, add = rows()
  local l = rex.call("session.list", {})
  for _, s in ipairs(l and l.sessions or {}) do
    if s.session_id ~= ctx.session_id then
      local label = (s.label and s.label ~= "") and s.label or s.session_id
      add{ id = s.session_id, title = label, subtitle = "session", icon = "terminal" }
    end
  end
  local root = git_root(cwd_of(ctx))
  if root then
    for _, w in ipairs(worktrees(root)) do
      local p = w.worktree and w.worktree.path
      if type(p) == "string" then
        local name = type(w.branch) == "string" and w.branch or basename(p)
        add{ id = "dir:" .. p, title = name, subtitle = p, icon = "branch" }
      end
    end
  end
  for _, p in ipairs(bookmarks()) do
    add{ id = "dir:" .. p, title = basename(p), subtitle = p, icon = "star" }
  end
  for p in lines(out({ "zoxide", "query", "-l" })) do
    add{ id = "dir:" .. p, title = basename(p), subtitle = p, icon = "folder" }
  end
  return list
end

local function go(sid)
  rex.client.queue("session.select", { session_id = sid })
  return { state = "switched", session_id = sid }
end

local function open_dir(path, name)
  local s = workspace.open(path, name)
  return go(s.session_id)
end

local function has_branch(root, name)
  local local_ref = lib.run({ "git", "-C", root, "show-ref", "--verify", "--quiet", "refs/heads/" .. name })
  if local_ref and local_ref.ok then return true end
  return (out({ "git", "-C", root, "for-each-ref", "refs/remotes/*/" .. name }) or "") ~= ""
end

local function make_worktree(ctx, name)
  local root = git_root(cwd_of(ctx))
  if not root then fail("the focused pane is not in a git repository") end
  local argv = { "wt", "-C", root, "switch", name, "--no-cd" }
  if not has_branch(root, name) then argv = { "wt", "-C", root, "switch", "--create", name, "--no-cd" } end
  local r = lib.run(argv)
  if not (r and r.ok) then fail("wt switch failed: " .. tostring(chomp(r and r.stderr))) end
  local path, repo
  for _, w in ipairs(worktrees(root)) do
    local p = w.worktree and w.worktree.path
    if w.branch == name then path = p end
    if w.worktree and w.worktree.main then repo = basename(p) end
  end
  if not path then fail("wt made no worktree for " .. name) end
  return open_dir(path, (repo or basename(root)) .. "-" .. name:gsub("/", "-"))
end

rex.action{
  name = "rows_switch", title = "Rows: Switch", category = "Pickers",
  run = function(ctx) return { rows = M.switch_rows(ctx) } end,
}

rex.action{
  name = "pick_switch", title = "Switch Session, Worktree or Folder", category = "Pickers",
  args = { id = "string?", name = "string?" },
  run = function(ctx, args)
    if args.name then return make_worktree(ctx, args.name) end
    local id = args.id
    if not id then
      local answer = lib.ask{
        title = "Switch", placeholder = "Session, worktree or folder; type a name for a new worktree",
        items = M.switch_rows(ctx), allow_other = true,
      }
      if answer == nil then return { state = "cancelled" } end
      if type(answer) == "table" then
        local name, why = rex.ui.input{ title = "New worktree", value = answer.text }
        if not name or name == "" then return { state = why or "cancelled" } end
        return make_worktree(ctx, name)
      end
      id = answer
    end
    if id:match("^session:") then return go(id) end
    local path = id:match("^dir:(.+)$")
    if not path then fail("no row " .. id) end
    return open_dir(path, basename(path))
  end,
}

rex.action{
  name = "toggle_bookmark", title = "Toggle Bookmark", category = "Pickers",
  args = { path = "string?" },
  run = function(ctx, args)
    local path = args.path or cwd_of(ctx)
    if not path then fail("no folder to bookmark") end
    path = path:gsub("/+$", "")
    if path == "" then path = "/" end
    local d = lib.run({ "/bin/test", "-d", path })
    if not (d and d.ok) then fail("not a folder: " .. path) end
    lib.run({ "/bin/mkdir", "-p", (BOOKMARKS:match("^(.*)/[^/]+$")) })
    local kept, had = {}, false
    for _, p in ipairs(bookmarks()) do
      if p == path then had = true else kept[#kept + 1] = p end
    end
    if not had then
      local f, err = io.open(BOOKMARKS, "a")
      if not f then fail(err) end
      f:write(path .. "\n")
      f:close()
      return { path = path, bookmarked = true }
    end
    local tmp = BOOKMARKS .. ".tmp"
    local f, err = io.open(tmp, "w")
    if not f then fail(err) end
    for _, p in ipairs(kept) do f:write(p .. "\n") end
    f:close()
    local ok, rerr = os.rename(tmp, BOOKMARKS)
    if not ok then
      os.remove(tmp)
      fail(rerr)
    end
    return { path = path, bookmarked = false }
  end,
}

function M.read_rows(ctx, any)
  local list, add = rows()
  local cwd = cwd_of(ctx)
  if not cwd then return list end
  local root = git_root(cwd)
  local globs = {}
  if not any then
    for _, g in ipairs(MD_GLOBS) do append(globs, { "--glob", g }) end
  end
  local argv = append(append({ "rg", "--files", "--hidden", "--follow" }, WALK), globs)
  if not root then append(argv, LOOSE) end
  local found = {}
  for rel in lines(out(argv, cwd)) do found[#found + 1] = rel end
  local scratch = (root or cwd) .. "/.scratchpad"
  if not any then
    local s = append(append({ "rg", "--files", "--hidden", "--no-ignore", "--follow" }, WALK), globs)
    for p in lines(out(append(s, { "--", scratch }), cwd)) do found[#found + 1] = p end
  end
  table.sort(found)
  for _, p in ipairs(found) do
    local full = p:sub(1, 1) == "/" and p or (cwd .. "/" .. p)
    local title = full:sub(1, #cwd + 1) == cwd .. "/" and full:sub(#cwd + 2) or full
    add{ id = full, title = title, icon = any and "code" or "document" }
  end
  return list
end

local function read_action(name, title, any)
  rex.action{
    name = name, title = title, category = "Pickers",
    args = { id = "string?" },
    run = function(ctx, args)
      local file = args.id
      if not file then
        file = lib.ask{ title = title, items = M.read_rows(ctx, any) }
        if file == nil then return { state = "cancelled" } end
      end
      return side.toggle(ctx, "reader", file)
    end,
  }
end

rex.action{
  name = "rows_read", title = "Rows: Read", category = "Pickers",
  args = { any = "boolean?" },
  run = function(ctx, args) return { rows = M.read_rows(ctx, args.any) } end,
}

read_action("pick_read", "Read a Document", false)
read_action("pick_read_any", "Read a File", true)

local function copy(script, file)
  local r = lib.run({ "/bin/sh", "-c", script, "copy", lib.COPY, file })
  if not (r and r.ok) then fail("copy failed: " .. tostring(chomp(r and r.stderr))) end
  return { file = file, copied = true }
end

rex.action{
  name = "reader_copy_file", title = "Reader: Copy File", category = "Pickers",
  run = function(ctx) return copy('exec "$1" < "$2"', (side.reader(ctx.session_id))) end,
}

rex.action{
  name = "reader_copy_path", title = "Reader: Copy Path", category = "Pickers",
  run = function(ctx) return copy('printf %s "$2" | "$1"', (side.reader(ctx.session_id))) end,
}

rex.action{
  name = "reader_edit", title = "Reader: Edit in Pane", category = "Pickers",
  run = function(ctx)
    local sid = ctx.session_id
    local file, bid = side.reader(sid)
    local r, err = rex.session.new_split{
      session_id = sid, anchor_id = bid, direction = "horizontal", side = "before", focus = true,
      layout = rex.layout.block{
        flavor = lib.SHELL, label = "edit:" .. basename(file),
        options = { command = { lib.EDITOR, file }, cwd = file:match("^(.*)/[^/]*$") },
      },
    }
    if not r then fail(err) end
    return { block_id = r.block_ids[1], file = file }
  end,
}

local function plain(s)
  s = s:gsub("\27%]8;[^;\27\7]*;([^\27\7]*)\27\\", " %1 ")
  s = s:gsub("\27%]8;[^;\27\7]*;([^\27\7]*)\7", " %1 ")
  s = s:gsub("\27%[[%d;]*[CGHf]", " ")
  s = s:gsub("\27%[[\48-\63]*[\32-\47]*[\64-\126]", "")
  s = s:gsub("\27%][^\27\7]*\27\\", "")
  s = s:gsub("\27%][^\27\7]*\7", "")
  s = s:gsub("\27.", "")
  return s
end

local function tidy(u)
  while true do
    u = u:gsub("[.,;:!?]+$", "")
    local _, open = u:gsub("%(", "")
    local _, close = u:gsub("%)", "")
    if not (close > open and u:sub(-1) == ")") then return u end
    u = u:sub(1, -2)
  end
end

function M.link_rows(ctx, bid)
  local sid = ctx.session_id
  bid = bid or lib.source(ctx)
  if not bid then fail("no pane to read links from") end
  local r = lib.bcall(sid, bid, "format", { format = "vt", unwrap = true })
    or lib.bcall(sid, bid, "format", { format = "vt" })
  if not (r and r.content) then fail("no screen text in " .. bid) end
  local found = {}
  for u in plain(r.content):gmatch("https?://[^%]%[%s<>\"'`]+") do found[#found + 1] = tidy(u) end
  local list, add = rows()
  for i = #found, 1, -1 do add{ id = found[i], title = found[i], icon = "link" } end
  return list
end

rex.action{
  name = "rows_link", title = "Rows: Links", category = "Pickers",
  args = { block = "string?" },
  run = function(ctx, args) return { rows = M.link_rows(ctx, args.block) } end,
}

rex.action{
  name = "pick_link", title = "Open a Link", category = "Pickers",
  args = { id = "string?" },
  run = function(ctx, args)
    local url = args.id
    if not url then
      local list = M.link_rows(ctx)
      if #list == 0 then fail("no links in this pane") end
      url = lib.ask{ title = "Open a Link", items = list }
      if url == nil then return { state = "cancelled" } end
    end
    local r = lib.run({ lib.OPEN, url })
    if not (r and r.ok) then fail("open failed: " .. tostring(chomp(r and r.stderr))) end
    return { state = "opened", url = url }
  end,
}

function M.key_rows()
  local k, err = rex.call("client.keymap", {})
  if not k then fail(err) end
  local titles = {}
  for _, a in ipairs(k.actions or {}) do titles[a.name] = a.title end
  local list, add = rows()
  for i, b in ipairs(k.bindings or {}) do
    local keys = table.concat(b.keys or {}, " ")
    if b.mode then keys = b.mode .. ": " .. keys end
    add{ id = tostring(i), title = titles[b.action] or b.action, subtitle = keys, icon = "tag" }
  end
  return list, k.bindings or {}
end

rex.action{
  name = "rows_key", title = "Rows: Keys", category = "Pickers",
  run = function() return { rows = (M.key_rows()) } end,
}

rex.action{
  name = "pick_key", title = "Find a Key", category = "Pickers",
  args = { id = "string?" },
  run = function(_, args)
    local list, bindings = M.key_rows()
    local id = args.id
    if not id then
      id = lib.ask{ title = "Find a Key", items = list }
      if id == nil then return { state = "cancelled" } end
    end
    local b = bindings[tonumber(id) or 0]
    if not b then fail("no key row " .. id) end
    rex.client.queue(b.action, b.args)
    return { state = "queued", action = b.action }
  end,
}

return M
