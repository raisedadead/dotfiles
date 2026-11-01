local lib = require("lib")

rex.action{
  name = "handoff_float", title = "Hand-off", category = "Agents",
  args = { argv = "array", cwd = "string", result = "string", caller = "integer" },
  run = function(ctx, args)
    local sid = ctx.session_id
    local here, err = lib.where(sid)
    if not here then error(err, 0) end
    local w = ctx.block_id and lib.window_of(sid, ctx.block_id) or here.window_id
    local focus = w == here.window_id
    local cmd = { lib.BIN .. "rex-handoff", "--inner", args.result, tostring(args.caller), "--" }
    for _, a in ipairs(args.argv) do cmd[#cmd + 1] = tostring(a) end
    local r, e = rex.session.new_layer{
      session_id = sid, window_id = w, focus = focus, bounds = { 0.15, 0.25, 0.7, 0.5 },
      layout = rex.layout.block{
        flavor = lib.SHELL, label = "handoff", options = { command = cmd, cwd = args.cwd },
      },
    }
    if not r then error(e, 0) end
    return { block_id = r.block_ids[1], window_id = w, focused = focus }
  end,
}
