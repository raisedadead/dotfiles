local colors = require("colors")
local icons = require("icons")

local mode = sbar.add("item", "mode_indicator", {
	position = "left",
	drawing = "off",
	updates = "on",
	icon = {
		string = icons.service,
		font = { family = colors.icon_font, style = "Regular", size = 14.0 },
		color = colors.crust,
		padding_left = 10,
		padding_right = 5,
	},
	label = {
		string = "SERVICE",
		font = { family = colors.font, style = "Bold", size = 13.0 },
		color = colors.crust,
		padding_right = 10,
	},
	background = { color = colors.red, corner_radius = 5, height = 22 },
})

mode:subscribe("aerospace_mode_change", function(env)
	mode:set({ drawing = env.MODE == "service" and "on" or "off" })
end)
