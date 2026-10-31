local lib = require("lib")

rex.action{
  name = "probe_popup", title = "Probe: Popup", category = "Probe",
  run = function(ctx)
    local b, err = lib.popup(ctx, {
      label = "probe", bounds = { 0.3, 0.35, 0.4, 0.2 },
      cmd = { "sh", "-c", "echo 'Rex probe: this float closes in 2 s'; sleep 2" },
    })
    if not b then error(err, 0) end
    return { block_id = b }
  end,
}

rex.action{
  name = "probe_switch", title = "Probe: Switch Session", category = "Probe",
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

rex.bind("ctrl+alt+p", "probe_popup")
rex.bind("ctrl+alt+s", "probe_switch")
