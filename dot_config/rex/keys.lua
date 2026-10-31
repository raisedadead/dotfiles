local lib = require("lib")

local EDITORS = { nvim = true, vim = true }
local META = { left = "\27H", down = "\27J", up = "\27K", right = "\27L" }

rex.action{
  name = "nav", title = "Move Between Panes", category = "Panes",
  args = { dir = "string", block = "string?" },
  run = function(ctx, args)
    local seq = META[args.dir]
    if not seq then error("dir must be left, down, up or right", 0) end
    local bid = args.block or ctx.block_id
    local f = bid and lib.fg(ctx.session_id, bid)
    if f and lib.runs(f, EDITORS) then
      local r, err = lib.safe_write(ctx.session_id, bid, seq)
      if not r then error(err, 0) end
      return
    end
    rex.client.queue("pane.focus." .. args.dir)
  end,
}

rex.action{
  name = "close_pane", title = "Close Pane", category = "Panes",
  args = { block = "string?" },
  run = function(ctx, args)
    local bid = args.block or ctx.block_id
    if not bid then error("no pane to close", 0) end
    local r, err = rex.call("block.close", {
      session_id = ctx.session_id, block_id = bid,
    })
    if not r then error(err, 0) end
  end,
}

local bind = rex.bind

for _, d in ipairs({ { "h", "left" }, { "j", "down" }, { "k", "up" }, { "l", "right" } }) do
  bind("alt+shift+" .. d[1], "nav", { dir = d[2] })
  bind("ctrl+space>" .. d[1], "pane.focus." .. d[2])
  bind("resize/" .. d[1], "pane.resize", { direction = d[2], amount = 2 })
end

bind("alt+d", "pane.split.right")
bind("alt+shift+d", "pane.split.down")
bind("alt+shift+enter", "pane.zoom")
bind("alt+`", "client.tab.next")
bind("alt+shift+`", "client.tab.previous")
for i = 1, 9 do bind("alt+" .. i, "client.tab.goto", { index = i }) end
bind("alt+o", "session.switch")
bind("alt+tab", "session.next")
bind("alt+shift+tab", "session.previous")
bind("alt+n", "session.new")
bind("alt+m", "client.tab.new")
bind("alt+r", "session.rename")
bind("alt+shift+r", "client.tab.rename")
bind("alt+;", "client.palette.toggle")
bind("alt+p", "session.collapse")
bind("alt+u", "session.expand")
bind("alt+shift+a", "client.sidebar.activity.toggle")
bind("alt+t", "drawer_scratch")
bind("alt+g", "popup_lazygit")
bind("alt+i", "popup_reader")
bind("alt+e", "popup_urls")
bind("alt+w", "popup_workspace")
bind("alt+shift+/", "popup_keys")
bind("ctrl+space>shift+/", "popup_keys")

bind("ctrl+space>shift+\\", "pane.split.right")
bind("ctrl+space>-", "pane.split.down")
bind("ctrl+space>x", "close_pane")
bind("ctrl+space>f", "pane.zoom")
bind("ctrl+space>e", "pane.balance")
bind("ctrl+space>r", "client.config.reload")
bind("ctrl+space>shift+r", "client.mode.enter", { name = "resize" })
bind("ctrl+space>m", "pane.move_to_new_tab")
bind("ctrl+space>p", "pane.float")
bind("ctrl+space>y", "pane.copy_id")

rex.mode("resize", { exclusive = true })
bind("resize/enter", "client.mode.exit")
