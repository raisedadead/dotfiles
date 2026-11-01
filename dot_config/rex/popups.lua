local lib = require("lib")

local WIDE = { 0.1, 0.1, 0.8, 0.8 }

local function popup_action(name, title, bounds, argv)
  rex.action{
    name = "popup_" .. name, title = title, category = "Popups",
    run = function(ctx)
      local b, err = lib.popup(ctx, {
        label = "popup:" .. name, bounds = bounds, cmd = argv(ctx),
      })
      if not b then error(err, 0) end
      return { block_id = b }
    end,
  }
end

popup_action("lazygit", "Lazygit", { 0.15, 0.1, 0.7, 0.8 }, function()
  return {
    "/bin/sh", "-c",
    '[ -f "$1" ] || exec lazygit; c=$(lazygit -cd)/config.yml; '
      .. '[ -f "$c" ] && set -- "$c,$1"; exec lazygit -ucf "$1"',
    "lazygit", lib.DIR .. "/lazygit.yml",
  }
end)

popup_action("reader", "Reader", WIDE, function()
  return { lib.BIN .. "rex-reader" }
end)

popup_action("keys", "Key Bindings", WIDE, function()
  return { os.getenv("HOME") .. "/.bin/keys" }
end)

popup_action("urls", "Open a Link", { 0.25, 0.2, 0.5, 0.6 }, function(ctx)
  return { lib.BIN .. "rex-urls", ctx.session_id, lib.source(ctx) or "" }
end)
