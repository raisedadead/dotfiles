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
