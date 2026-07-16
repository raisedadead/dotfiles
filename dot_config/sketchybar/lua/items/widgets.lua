local colors = require("colors")
local icons = require("icons")

local plugin = os.getenv("HOME") .. "/.config/sketchybar/plugins/"

sbar.add("item", "clock", {
	position = "right",
	update_freq = 10,
	icon = { string = icons.clock, color = colors.sapphire, font = { size = 13.0 } },
	label = { font = { size = 12.0, features = "tnum" } },
	popup = {
		background = {
			color = colors.surface0,
			corner_radius = 8,
			border_width = 2,
			border_color = colors.surface2,
		},
		horizontal = "off",
		align = "right",
		y_offset = 2,
	},
	script = plugin .. "clock.sh",
	click_script = plugin .. "calendar_popup.sh",
})

sbar.add("item", "calendar", {
	position = "right",
	update_freq = 120,
	icon = { string = icons.calendar, color = colors.peach, font = { size = 13.0 } },
	label = { font = { size = 12.0 } },
	script = plugin .. "calendar.sh",
})

sbar.add("item", "weather", {
	position = "right",
	update_freq = 900,
	icon = { string = icons.weather, color = colors.sky, font = { size = 13.0 } },
	label = { font = { size = 12.0 } },
	script = plugin .. "weather.sh",
})

local tailscale = sbar.add("item", "tailscale", {
	position = "right",
	update_freq = 15,
	icon = { string = icons.net, color = colors.green, font = { size = 13.0 } },
	label = { font = { size = 12.0 } },
	script = plugin .. "tailscale.sh",
})

tailscale:subscribe("system_woke", function()
	sbar.exec("NAME=tailscale " .. plugin .. "tailscale.sh")
end)

sbar.add("item", "cpu", {
	position = "right",
	update_freq = 5,
	icon = { string = icons.cpu, color = colors.green, font = { size = 13.0 } },
	label = { font = { size = 12.0 } },
	script = plugin .. "cpu.sh",
})

sbar.add("bracket", "status", { "cpu", "tailscale", "weather", "calendar", "clock" }, {
	background = { color = colors.surface0, corner_radius = 8, height = 28 },
})
