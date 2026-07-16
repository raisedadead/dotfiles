local colors = require("colors")
local icons = require("icons")

local front_app = sbar.add("item", "front_app", {
	position = "center",
	icon = {
		font = { family = colors.app_font, style = "Regular", size = 16.0 },
		color = colors.mauve,
		padding_left = 10,
		padding_right = 4,
	},
	label = {
		font = { family = colors.font, style = "Bold", size = 13.0 },
		color = colors.text,
	},
	background = {
		color = colors.island,
		corner_radius = 12,
		height = 32,
		border_width = 1,
		border_color = colors.island_border,
	},
})

front_app:subscribe("front_app_switched", function(env)
	front_app:set({
		icon = { string = icons.app(env.INFO) },
		label = { string = env.INFO },
	})
end)
