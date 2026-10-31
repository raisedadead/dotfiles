local lib = require("lib")

local BOUNDS = { 0.08, 0.08, 0.84, 0.84 }
local LABEL = "drawer:scratch"

local function create(ctx, here)
  local src = ctx.block_id or here.focused
  local cwd
  if src then
    local _, c = lib.fg(ctx.session_id, src)
    cwd = c
  end
  local r, err = rex.session.new_layer{
    session_id = ctx.session_id, window_id = here.window_id, focus = true,
    bounds = BOUNDS,
    layout = rex.layout.block{
      flavor = lib.SHELL, label = LABEL, options = { cwd = cwd },
    },
  }
  if not r then error(err, 0) end
  return { state = "created", block_id = r.block_ids[1] }
end

local function show(ctx, here, b)
  local sid, bid = ctx.session_id, b.block_id
  local _, err = rex.session.move_block{
    session_id = sid, block_id = bid, anchor_block_id = here.anchor,
    direction = "horizontal", side = "after",
  }
  if err then error(err, 0) end
  _, err = rex.session.float_block{
    session_id = sid, block_id = bid, bounds = BOUNDS,
  }
  if err then error(err, 0) end
  rex.session.focus_block{ session_id = sid, block_id = bid }
  return { state = "shown", block_id = bid }
end

rex.action{
  name = "drawer_scratch", title = "Scratch Drawer", category = "Popups",
  run = function(ctx)
    local here, err = lib.where(ctx.session_id)
    if not here then error(err, 0) end
    local b = lib.find_label(ctx.session_id, LABEL)
    if not b then return create(ctx, here) end
    if b.placement ~= "detached" then
      rex.session.detach_block{ session_id = ctx.session_id, block_id = b.block_id }
      if here.focused == b.block_id then
        return { state = "hidden", block_id = b.block_id }
      end
      here = lib.where(ctx.session_id)
    end
    return show(ctx, here, b)
  end,
}
