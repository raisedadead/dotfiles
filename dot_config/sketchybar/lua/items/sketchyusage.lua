local colors = require("colors")
local icons = require("icons")
local binary = "/opt/homebrew/bin/sketchyusage"
local cache = os.getenv("XDG_CACHE_HOME") or (os.getenv("HOME") .. "/.cache")
local heartbeat = cache .. "/sketchyusage/heartbeat"
local heartbeat_limit = 180
local providers = {
	{ id = "claude", label = "Claude", color = colors.peach },
	{ id = "codex", label = "Codex", color = colors.teal },
}
local items, names = {}, {}

for index, provider in ipairs(providers) do
	local name = "sketchyusage." .. provider.id
	local rightmost = index == 1
	local leftmost = index == #providers
	items[index] = sbar.add("item", name, {
		position = "right",
		-- workaround: FelixKratz/SketchyBar#863
		padding_left = leftmost and 4 or 0,
		padding_right = rightmost and 4 or 0,
		click_script = binary .. " toggle",
		icon = {
			string = icons.app(provider.label),
			color = provider.color,
			font = { family = colors.app_font, size = 17 },
			padding_left = leftmost and 10 or 9,
		},
		label = {
			string = "—",
			color = colors.overlay1,
			font = { size = 13, features = "tnum" },
			padding_right = rightmost and 10 or 9,
		},
	})
	table.insert(names, name)
end

local function beat_age()
	local file = io.open(heartbeat, "r")
	if not file then
		return nil
	end
	local beat = file:read("n")
	file:close()
	return beat and os.time() - beat
end

local function check()
	local age = beat_age()
	if not age or age > heartbeat_limit then
		for _, item in ipairs(items) do
			item:set({ label = { string = "— !", color = colors.overlay1 } })
		end
	end
end

items[1]:set({ update_freq = 60 })
items[1]:subscribe("routine", check)
items[1]:subscribe({ "forced", "system_woke" }, function()
	sbar.exec(binary .. " push")
end)

return names
