local lib = require("lib")

local M = {}

local BOUNDS = { 0.08, 0.08, 0.84, 0.84 }
local DRAWER = "drawer:scratch"
local RATIO = 0.6
local GLOW_STYLE = os.getenv("HOME") .. "/.config/glow/mocha.json"
local MARKDOWN = { md = true, markdown = true, mdown = true, mkd = true, mkdn = true, mdx = true }
local BOUNDS_OF = {}
local BACK = {}
local FILES = {}

local function fail(err) error(err, 0) end

local function close(sid, bid)
  local _, err = rex.call("block.close", { session_id = sid, block_id = bid })
  if err then fail(err) end
end

local function give_back(sid, bid)
  local back = BACK[bid] or {}
  BACK[bid] = nil
  if back.ret then rex.session.focus_block{ session_id = sid, block_id = back.ret } end
  if back.zoomed then
    rex.session.zoom_block{ session_id = sid, block_id = back.zoomed, zoom = true }
  end
end

local function float_create(ctx, here)
  local sid = ctx.session_id
  local src = lib.source(ctx, here)
  local cwd
  if src then
    local _, c = lib.fg(sid, src)
    cwd = c
  end
  local r, err = rex.session.new_layer{
    session_id = sid, window_id = here.window_id, focus = true,
    bounds = BOUNDS_OF[sid] or BOUNDS,
    layout = rex.layout.block{
      flavor = lib.SHELL, label = DRAWER, options = { cwd = cwd },
    },
  }
  if not r then fail(err) end
  BACK[r.block_ids[1]] = { ret = here.focused, zoomed = here.zoomed }
  return { state = "created", block_id = r.block_ids[1] }
end

local function float_show(ctx, here, bid)
  local sid = ctx.session_id
  local r, err = rex.session.new_layer{
    session_id = sid, window_id = here.window_id, focus = false,
    bounds = BOUNDS_OF[sid] or BOUNDS,
    layout = rex.layout.block{
      flavor = lib.SHELL,
      options = { command = { "/bin/sleep", "60" }, shell = "none" },
    },
  }
  if not r then fail(err) end
  local ph = r.block_ids[1]
  local _, merr = rex.session.move_block{
    session_id = sid, block_id = bid, anchor_block_id = ph,
  }
  rex.call("block.close", { session_id = sid, block_id = ph })
  if merr then fail(merr) end
  BACK[bid] = { ret = here.focused, zoomed = here.zoomed }
  rex.session.focus_block{ session_id = sid, block_id = bid }
  return { state = "shown", block_id = bid }
end

local function float_hide(ctx, here, bid)
  local sid = ctx.session_id
  local layer = here.floating[bid]
  if layer then BOUNDS_OF[sid] = layer.bounds end
  local _, err = rex.session.detach_block{ session_id = sid, block_id = bid }
  if err then fail(err) end
  give_back(sid, bid)
  return { state = "hidden", block_id = bid }
end

rex.action{
  name = "drawer_scratch", title = "Scratch Drawer", category = "Popups",
  run = function(ctx)
    local sid = ctx.session_id
    local here, err = lib.where(sid)
    if not here then fail(err) end
    local b, ferr = lib.find_label(sid, DRAWER)
    if ferr then fail(ferr) end
    if not b then return float_create(ctx, here) end
    local bid = b.block_id
    if here.focused == bid then return float_hide(ctx, here, bid) end
    if here.floating[bid] then
      rex.session.focus_block{ session_id = sid, block_id = bid }
      return { state = "shown", block_id = bid }
    end
    if b.placement ~= "detached" then
      local _, derr = rex.session.detach_block{ session_id = sid, block_id = bid }
      if derr then fail(derr) end
      here, err = lib.where(sid)
      if not here then fail(err) end
    end
    return float_show(ctx, here, bid)
  end,
}

local KINDS = {
  git = function()
    return {
      "/bin/sh", "-c",
      '[ -f "$1" ] || exec lazygit; c=$(lazygit -cd)/config.yml; '
        .. '[ -f "$c" ] && set -- "$c,$1"; exec lazygit -ucf "$1"',
      "lazygit", lib.DIR .. "/lazygit.yml",
    }
  end,
  reader = function(file)
    local ext = (file:match("%.([%w]+)$") or ""):lower()
    if MARKDOWN[ext] then
      return {
        "/bin/sh", "-c",
        'w=$(tput cols 2>/dev/null) || w=80; exec glow -p -s "$1" -w "$w" -- "$2"',
        "glow", GLOW_STYLE, file,
      }
    end
    return { "/bin/sh", "-c", 'exec bat --paging=always --pager="less -R" -- "$1"', "bat", file }
  end,
}

local function is_side(label)
  return (label or ""):match("^side:") ~= nil
end

local function beside(node, bid)
  local s = node and node.split
  if not s then return nil end
  if s.after and s.after.block_id == bid and s.before then return s.before.block_id end
  return beside(s.before, bid) or beside(s.after, bid)
end

local function main_of(here)
  local f = here.focused
  if f and here.floating[f] then return here.anchor end
  if not (f and is_side(here.labels[f])) then return f end
  local back = BACK[f]
  if back and back.ret and here.labels[back.ret] then return back.ret end
  for _, l in ipairs(here.layers) do
    local m = beside(l.layout, f)
    if m and not is_side(here.labels[m]) then return m end
  end
  for _, l in ipairs(here.layers) do
    if l.kind == "tiled" then
      for _, b in ipairs(l.blocks or {}) do
        if not is_side(b.label) then return b.block_id end
      end
    end
  end
end

local function root(sid, bid)
  local _, cwd = lib.fg(sid, bid)
  if not cwd then return nil end
  local r = rex.exec({ "/usr/bin/git", "-C", cwd, "rev-parse", "--show-toplevel" })
  if r and r.ok then return (r.stdout:gsub("%s+$", "")) end
  return cwd
end

local function sweep(sid, blocks, windows)
  local kept = {}
  for _, b in ipairs(blocks) do
    local wid = (b.label or ""):match("^side:[^:]+:(.+)$")
    if wid and b.placement == "detached" and not windows[wid] then
      close(sid, b.block_id)
    else
      kept[#kept + 1] = b
    end
  end
  return kept
end

local function side_create(sid, here, main, label, cmd)
  local _, cwd = lib.fg(sid, main)
  local r, err = rex.session.new_split{
    session_id = sid, anchor_id = main, direction = "horizontal", side = "after",
    ratio = RATIO, focus = true,
    layout = rex.layout.block{
      flavor = lib.SHELL, label = label, options = { command = cmd, cwd = cwd },
    },
  }
  if not r then fail(err) end
  local bid = r.block_ids[1]
  BACK[bid] = { ret = main, zoomed = here.zoomed }
  return { state = "created", block_id = bid }
end

local function side_show(sid, here, main, bid)
  local _, err = rex.session.move_block{
    session_id = sid, block_id = bid, anchor_block_id = main,
    direction = "horizontal", side = "after", ratio = RATIO,
  }
  if err then fail(err) end
  BACK[bid] = { ret = main, zoomed = here.zoomed }
  rex.session.focus_block{ session_id = sid, block_id = bid }
  return { state = "shown", block_id = bid }
end

local function side_hide(sid, main, bid)
  local back = BACK[bid] or {}
  BACK[bid] = { ret = back.ret or main, zoomed = back.zoomed }
  local _, err = rex.session.detach_block{ session_id = sid, block_id = bid }
  if err then fail(err) end
  give_back(sid, bid)
  return { state = "hidden", block_id = bid }
end

function M.toggle(ctx, kind, file)
  local sid = ctx.session_id
  local here, err = lib.where(sid)
  if not here then fail(err) end
  local v, verr = rex.session.view{ session_id = sid }
  if not v then fail(verr) end
  local windows = {}
  for _, w in ipairs(v.windows or {}) do windows[w.window_id] = true end
  local l, lerr = rex.session.list_blocks{ session_id = sid }
  if not l then fail(lerr) end
  local label = "side:" .. kind .. ":" .. here.window_id
  local b
  for _, x in ipairs(sweep(sid, l.blocks, windows)) do
    if x.label == label then b = x end
  end
  local main = main_of(here)
  if not main then fail("no main pane in " .. here.window_id) end
  if b and file then
    close(sid, b.block_id)
    b = nil
  end
  if b and here.focused == b.block_id then return side_hide(sid, main, b.block_id) end
  if b and b.placement ~= "detached" then
    rex.session.focus_block{ session_id = sid, block_id = b.block_id }
    return { state = "focused", block_id = b.block_id }
  end
  if b and root(sid, b.block_id) ~= root(sid, main) then
    close(sid, b.block_id)
    b = nil
  end
  if b then return side_show(sid, here, main, b.block_id) end
  if kind == "reader" and not file then fail("no file to read") end
  local r = side_create(sid, here, main, label, KINDS[kind](file))
  FILES[r.block_id] = file
  return r
end

function M.reader(sid)
  local here, err = lib.where(sid)
  if not here then fail(err) end
  local b = lib.find_label(sid, "side:reader:" .. here.window_id)
  local file = b and FILES[b.block_id]
  if not file then fail("no file in the reader side pane") end
  return file, b.block_id
end

rex.action{
  name = "side_git", title = "Git Side Pane", category = "Panes",
  run = function(ctx) return M.toggle(ctx, "git") end,
}

rex.action{
  name = "side_reader", title = "Reader Side Pane", category = "Panes",
  args = { file = "string?" },
  run = function(ctx, args) return M.toggle(ctx, "reader", args.file) end,
}

return M
