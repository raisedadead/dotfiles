local colors = require("colors")

return function(name, position, overrides)
	local props = {
		position = position,
		padding_left = 0,
		padding_right = 0,
		icon = {
			string = "│",
			font = { family = colors.font, size = 13 },
			color = colors.surface2,
			padding_left = 0,
			padding_right = 6,
		},
		label = { drawing = false },
	}
	for key, value in pairs(overrides or {}) do
		props[key] = value
	end
	return sbar.add("item", name, props)
end
