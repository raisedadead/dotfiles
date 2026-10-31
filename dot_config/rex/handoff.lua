local lib = require("lib")

rex.action{
  name = "handoff_float", title = "Hand-off", category = "Agents",
  args = { argv = "array" },
  run = function(ctx, args)
    local cmd = { lib.BIN .. "rex-handoff", "--inner", "--" }
    for _, a in ipairs(args.argv) do cmd[#cmd + 1] = tostring(a) end
    local b, err = lib.popup(ctx, {
      label = "handoff", bounds = { 0.15, 0.25, 0.7, 0.5 }, cmd = cmd, login = true,
      window_id = ctx.block_id and lib.window_of(ctx.session_id, ctx.block_id),
    })
    if not b then error(err, 0) end
    return { block_id = b }
  end,
}
