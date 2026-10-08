local colors = require("colors")
local icons = require("icons")
local separator = require("separator")

local clock = sbar.add("item", "clock", {
	position = "right",
	update_freq = 30,
	icon = { string = icons.clock, color = colors.sapphire, font = { size = 14.0 } },
	label = { font = { size = 13.0, features = "tnum" } },
})

clock:subscribe({ "routine", "forced", "system_woke" }, function()
	clock:set({ label = { string = os.date("%a %d %b  %H:%M") } })
end)

separator("status.date_separator", "right")

local utc_clock = sbar.add("item", "utc_clock", {
	position = "right",
	update_freq = 30,
	icon = { string = icons.utc, color = colors.teal, font = { size = 14.0 } },
	label = { font = { size = 13.0, features = "tnum" } },
})

utc_clock:subscribe({ "routine", "forced", "system_woke" }, function()
	utc_clock:set({ label = { string = "UTC " .. os.date("!%H:%M") } })
end)

separator("status.usage_separator", "right")
local status_items = require("items.usage")
separator("status.sketchyusage_separator", "right")
for _, name in ipairs(require("items.sketchyusage")) do
	table.insert(status_items, 1, name)
end
for _, name in ipairs({
	"status.sketchyusage_separator",
	"status.usage_separator",
	"utc_clock",
	"status.date_separator",
	"clock",
}) do
	table.insert(status_items, name)
end

sbar.add("bracket", "status", status_items, {
	background = {
		color = colors.island,
		corner_radius = 14,
		height = 28,
		border_width = 1,
		border_color = colors.island_border,
	},
})
