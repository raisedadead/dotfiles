local lib = require("lib")

local BOUNDS = { 0.08, 0.08, 0.84, 0.84 }
local LABEL = "drawer:scratch"
local BOUNDS_OF = {}
local BACK = {}

local function remember(bid, here)
  BACK[bid] = { ret = here.focused, zoomed = here.zoomed }
end

local function create(ctx, here)
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
      flavor = lib.SHELL, label = LABEL, options = { cwd = cwd },
    },
  }
  if not r then error(err, 0) end
  remember(r.block_ids[1], here)
  return { state = "created", block_id = r.block_ids[1] }
end

local function show(ctx, here, bid)
  local sid = ctx.session_id
  local r, err = rex.session.new_layer{
    session_id = sid, window_id = here.window_id, focus = false,
    bounds = BOUNDS_OF[sid] or BOUNDS,
    layout = rex.layout.block{
      flavor = lib.SHELL,
      options = { command = { "/bin/sleep", "60" }, shell = "none" },
    },
  }
  if not r then error(err, 0) end
  local ph = r.block_ids[1]
  local _, merr = rex.session.move_block{
    session_id = sid, block_id = bid, anchor_block_id = ph,
  }
  rex.call("block.close", { session_id = sid, block_id = ph })
  if merr then error(merr, 0) end
  remember(bid, here)
  rex.session.focus_block{ session_id = sid, block_id = bid }
  return { state = "shown", block_id = bid }
end

local function hide(ctx, here, bid)
  local sid = ctx.session_id
  local layer = here.floating[bid]
  if layer then BOUNDS_OF[sid] = layer.bounds end
  local _, err = rex.session.detach_block{ session_id = sid, block_id = bid }
  if err then error(err, 0) end
  local back = BACK[bid] or {}
  BACK[bid] = nil
  if back.ret then rex.session.focus_block{ session_id = sid, block_id = back.ret } end
  if back.zoomed then
    rex.session.zoom_block{ session_id = sid, block_id = back.zoomed, zoom = true }
  end
  return { state = "hidden", block_id = bid }
end

rex.action{
  name = "drawer_scratch", title = "Scratch Drawer", category = "Popups",
  run = function(ctx)
    local sid = ctx.session_id
    local here, err = lib.where(sid)
    if not here then error(err, 0) end
    local b, ferr = lib.find_label(sid, LABEL)
    if ferr then error(ferr, 0) end
    if not b then return create(ctx, here) end
    local bid = b.block_id
    if here.focused == bid then return hide(ctx, here, bid) end
    if here.floating[bid] then
      rex.session.focus_block{ session_id = sid, block_id = bid }
      return { state = "shown", block_id = bid }
    end
    if b.placement ~= "detached" then
      local _, derr = rex.session.detach_block{ session_id = sid, block_id = bid }
      if derr then error(derr, 0) end
      here, err = lib.where(sid)
      if not here then error(err, 0) end
    end
    return show(ctx, here, bid)
  end,
}
