local colors = require("colors")
local icons = require("icons")
local binary = "'" .. (os.getenv("HOME") .. "/.local/bin/sketchyusage"):gsub("'", "'\\''") .. "'"
local providers = {
	{ id = "claude", label = "Claude", color = colors.peach },
	{ id = "codex", label = "Codex", color = colors.teal },
}
local names = {}

for index, provider in ipairs(providers) do
	local name = "sketchyusage." .. provider.id
	local rightmost = index == 1
	local leftmost = index == #providers
	local item = sbar.add("item", name, {
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
			font = { size = 13, features = "tnum" },
			padding_right = rightmost and 10 or 9,
		},
	})
	if rightmost then
		item:subscribe({ "forced", "system_woke" }, function()
			sbar.exec(binary .. " push")
		end)
	end
	table.insert(names, name)
end

return names
