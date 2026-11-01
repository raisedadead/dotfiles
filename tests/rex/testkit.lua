local lib = require("lib")

rex.action{
  name = "t_bin", title = "Test: helper directory", category = "Test",
  run = function() return { bin = lib.BIN } end,
}

rex.action{
  name = "t_env", title = "Test: server environment", category = "Test",
  run = function()
    local r = {}
    for _, k in ipairs{ "PATH", "SHELL", "HOME", "LANG", "LC_ALL", "TERM", "TERM_PROGRAM",
      "ZDOTDIR", "XDG_CONFIG_HOME", "REX_SESSION", "REX_BLOCK", "SANDBOX_CALLER_ONLY" } do
      r[k] = os.getenv(k)
    end
    return r
  end,
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

rex.action{
  name = "t_popup", title = "Test: popup", category = "Test",
  run = function(ctx)
    local b, err = lib.popup(ctx, {
      label = "t_popup", bounds = { 0.3, 0.35, 0.4, 0.2 },
      cmd = { "sh", "-c", "echo 'Rex test popup'; sleep 2" },
    })
    if not b then error(err, 0) end
    return { block_id = b }
  end,
}

rex.action{
  name = "t_switch", title = "Test: switch session", category = "Test",
  run = function(ctx)
    local l, err = rex.call("session.list", {})
    if not l then error(err, 0) end
    for _, s in ipairs(l.sessions) do
      if s.session_id ~= ctx.session_id then
        rex.client.queue("session.select", { session_id = s.session_id })
        return { session_id = s.session_id }
      end
    end
    error("no other session", 0)
  end,
}
