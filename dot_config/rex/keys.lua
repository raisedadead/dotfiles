local lib = require("lib")

rex.action{
  name = "close_pane", title = "Close Pane", category = "Panes",
  args = { block = "string?", answer = "string?" },
  run = function(ctx, args)
    local sid, bid = ctx.session_id, args.block or ctx.block_id
    if not bid then error("no pane to close", 0) end
    local done, perr, agent = lib.close_popup(ctx, bid)
    if perr then error(perr, 0) end
    if done then return { block_id = bid, closed = true } end
    local answer = args.answer
    if not answer then
      local f = lib.fg(sid, bid)
      local what = f and (lib.agent_in(f) or f.name) or "this pane"
      answer = lib.ask{
        title = "Close " .. what .. "?",
        items = { { id = "close", title = "Close" }, { id = "keep", title = "Keep" } },
      }
    end
    if answer ~= "close" then return { block_id = bid, closed = false } end
    local _, err = rex.call("block.close", { session_id = sid, block_id = bid })
    if err then error(err, 0) end
    agent = agent or {}
    if agent.ret then rex.session.focus_block{ session_id = sid, block_id = agent.ret } end
    if agent.zoomed then
      rex.session.zoom_block{ session_id = sid, block_id = agent.zoomed, zoom = true }
    end
    return { block_id = bid, closed = true }
  end,
}

local function write_key(ctx, data)
  if not ctx.block_id then error("no pane to send the key to", 0) end
  local r, err = lib.unchecked_write(ctx.session_id, ctx.block_id, data)
  if not r then error(err, 0) end
  return r
end

rex.action{
  name = "enter_key", title = "Send Enter", category = "Panes",
  run = function(ctx) return write_key(ctx, "\r") end,
}

local bind = rex.bind
local function prefix(key, action, args) bind("ctrl+space>" .. key, action, args) end

bind("shift+cmd+e", "popup_urls")
bind("ctrl+shift+k", "client.scroll.page_up")
bind("ctrl+shift+j", "client.scroll.page_down")
bind("cmd+pageup", "client.scroll.page_up")
bind("cmd+pagedown", "client.scroll.page_down")
for _, k in ipairs({ "w", "e", "a", "s" }) do
  bind("ctrl+shift+" .. k, "pane.send_key", { key = "ctrl+alt+" .. k })
end

for _, d in ipairs({ { "h", "left" }, { "j", "down" }, { "k", "up" }, { "l", "right" } }) do
  bind("alt+" .. d[1], "pane.focus." .. d[2])
  bind("alt+shift+" .. d[1], "pane.resize", { direction = d[2], amount = 2 })
end
bind("alt+tab", "session.next")
bind("alt+shift+tab", "session.previous")
bind("alt+[", "client.navigate.back")
bind("alt+]", "client.navigate.forward")
bind("alt+`", "client.tab.next")
bind("alt+shift+`", "client.tab.previous")
bind("alt+o", "pick_switch")
bind("alt+g", "side_git")
bind("alt+r", "pick_read")
bind("alt+s", "drawer_scratch")
bind("alt+e", "pick_link")
bind("alt+a", "next_waiting")
bind("alt+shift+/", "pick_key")

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
