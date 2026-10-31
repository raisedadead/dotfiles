local lib = require("lib")

rex.action{
  name = "t_bin", title = "Test: helper directory", category = "Test",
  run = function() return { bin = lib.BIN } end,
}

rex.action{
  name = "t_write", title = "Test: safe_write", category = "Test",
  args = { block = "string", text = "string" },
  run = function(ctx, args)
    local r, err = lib.safe_write(ctx.session_id, args.block, args.text)
    if not r then error(err, 0) end
    return r
  end,
}
