local colors = require("colors")
local icons = require("icons")

local clock = sbar.add("item", "clock", {
	position = "right",
	update_freq = 30,
	icon = { string = icons.clock, color = colors.sapphire, font = { size = 13.0 } },
	label = { font = { size = 12.0, features = "tnum" } },
})

clock:subscribe({ "routine", "forced", "system_woke" }, function()
	clock:set({ label = { string = os.date("%a %d %b  %H:%M") } })
end)

local utc_clock = sbar.add("item", "utc_clock", {
	position = "right",
	update_freq = 30,
	icon = { string = icons.utc, color = colors.teal, font = { size = 13.0 } },
	label = { font = { size = 12.0, features = "tnum" } },
})

utc_clock:subscribe({ "routine", "forced", "system_woke" }, function()
	utc_clock:set({ label = { string = "UTC " .. os.date("!%H:%M") } })
end)

sbar.add("bracket", "status", { "utc_clock", "clock" }, {
	background = {
		color = colors.island,
		corner_radius = 12,
		height = 32,
		border_width = 1,
		border_color = colors.island_border,
	},
})
