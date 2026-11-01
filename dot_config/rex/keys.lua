local lib = require("lib")

local CONFIRM = [[
printf '\n  Close %s?\n\n  Enter or y: close · any other key: keep\n' "$3"
IFS= read -rsn1 key || exit 0
case $key in
'' | y | Y) exec rex ${REX_SERVER:+-S "$REX_SERVER"} --autostart=false block close -s "$1" "$2" ;;
esac
]]

rex.action{
  name = "close_pane", title = "Close Pane", category = "Panes",
  args = { block = "string?" },
  run = function(ctx, args)
    local sid, bid = ctx.session_id, args.block or ctx.block_id
    if not bid then error("no pane to close", 0) end
    local done, perr = lib.close_popup(ctx, bid)
    if perr then error(perr, 0) end
    if done then return { block_id = bid, closed = true } end
    local f = lib.fg(sid, bid)
    local what = f and (lib.agent_in(f) or f.name) or "this pane"
    local b, err = lib.popup(ctx, {
      label = "popup:close", bounds = { 0.3, 0.4, 0.4, 0.2 },
      window_id = lib.window_of(sid, bid),
      cmd = { "/bin/bash", "-c", CONFIRM, "close", sid, bid, what },
    })
    if not b then error(err, 0) end
    return { block_id = b }
  end,
}

local bind = rex.bind
local function prefix(key, action, args) bind("ctrl+space>" .. key, action, args) end

bind("alt+shift+enter", "pane.zoom")
bind("alt+;", "client.palette.toggle")
bind("alt+e", "popup_urls")
for _, k in ipairs({ "w", "e", "a", "s" }) do
  bind("ctrl+shift+" .. k, "pane.send_key", { key = "ctrl+alt+" .. k })
end

prefix("ctrl+space", "pane.send_key", { key = "ctrl+space" })
for _, d in ipairs({ { "h", "left" }, { "j", "down" }, { "k", "up" }, { "l", "right" } }) do
  prefix(d[1], "pane.focus." .. d[2])
  bind("resize/" .. d[1], "pane.resize", { direction = d[2], amount = 2 })
end
prefix("shift+\\", "pane.split.right")
prefix("-", "pane.split.down")
prefix("x", "close_pane")
prefix("f", "pane.zoom")
prefix("e", "pane.balance")
prefix("p", "pane.float")
prefix("shift+m", "pane.move_to_new_tab")
prefix("y", "pane.copy_id")
prefix("shift+r", "client.mode.enter", { name = "resize" })

prefix("m", "client.tab.new")
prefix(",", "client.tab.rename")
prefix("`", "client.tab.next")
prefix("shift+`", "client.tab.previous")
for i = 1, 9 do prefix(tostring(i), "client.tab.goto", { index = i }) end

prefix("o", "session.switch")
prefix("n", "session.new")
prefix("shift+4", "session.rename")
prefix("tab", "session.next")
prefix("shift+tab", "session.previous")
prefix("shift+p", "session.collapse")
prefix("shift+u", "session.expand")
prefix("shift+a", "client.sidebar.activity.toggle")

prefix("t", "drawer_scratch")
prefix("g", "popup_lazygit")
prefix("i", "popup_reader")
prefix("w", "popup_workspace")
prefix("shift+/", "popup_keys")
prefix("a", "next_waiting")
prefix("c", "agent_here")
prefix("q", "ask_pane")
prefix("r", "client.config.reload")

rex.mode("resize", { exclusive = true })
bind("resize/enter", "client.mode.exit")
bind("resize/escape", "client.mode.exit")
