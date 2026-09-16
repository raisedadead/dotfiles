local colors = require("colors")
local icons = require("icons")
local config = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local command = "/opt/homebrew/bin/python3 '" .. (config .. "/sketchybar/usage.py"):gsub("'", "'\\''") .. "'"
local providers = {
	{ id = "claude", label = "Claude", color = colors.peach },
	{ id = "codex", label = "Codex", color = colors.teal },
}
local items, names, rows = {}, {}, {}
local snapshot, pending, opened = {}, false, false
local read_error

local function remaining(row)
	if not row or (row.resets_at and row.resets_at <= os.time()) then
		return nil
	end
	return row.remaining
end

local function tint(value, fallback)
	if not value then
		return colors.overlay1
	elseif value <= 10 then
		return colors.red
	elseif value <= 25 then
		return colors.yellow
	end
	return fallback
end

for _, provider in ipairs(providers) do
	local name = "usage." .. provider.id
	items[provider.id] = sbar.add("item", name, {
		position = "right",
		padding_left = 4,
		padding_right = 4,
		icon = { string = icons.app(provider.label), color = provider.color, font = { family = colors.app_font, size = 16 } },
		label = { string = "—", font = { size = 12, features = "tnum" } },
	})
	table.insert(names, name)
end
local owner = items.claude
owner:set({
	update_freq = 900,
	popup = {
		align = "right",
		height = 26,
		y_offset = -10,
		background = { color = colors.mantle, border_color = colors.surface2, border_width = 1, corner_radius = 12 },
	},
})

local function row(left, right, color, size)
	local name = "usage.popup." .. (#rows + 1)
	sbar.add("item", name, {
		position = "popup.usage.claude",
		width = 480,
		padding_left = 0,
		padding_right = 0,
		icon = { string = left:gsub("%c", " "), color = color or colors.text, font = { family = colors.font, size = size or 13 }, width = right and 200 or 444, max_chars = right and 24 or 52, padding_left = 18, padding_right = 0 },
		label = { drawing = right ~= nil, string = right or "", color = color or colors.text, font = { family = colors.font, size = size or 13 }, width = 244, align = "right", padding_left = 0, padding_right = 18 },
		background = { drawing = false },
	})
	table.insert(rows, name)
end

local function render()
	owner:set({ popup = { drawing = false } })
	for _, name in ipairs(rows) do
		sbar.remove(name)
	end
	rows = {}
	for _, provider in ipairs(providers) do
		local data = snapshot[provider.id] or {}
		local value = remaining(data.weekly)
		local failure = read_error or data.error
		local stale = failure or (data.updated_at and os.time() - data.updated_at > 1800)
		items[provider.id]:set({ label = { string = (value and (value .. "%") or "—") .. (stale and " !" or ""), color = tint(value, provider.color) } })
		row(provider.label, nil, provider.color, 14)
		local count = 0
		for _, window in ipairs(data.windows or {}) do
			if provider.id ~= "codex" or not window.label:lower():find("codex-spark", 1, true) then
				local available = remaining(window)
				local reset = window.resets_at
				local detail = available and (available .. "%" .. (stale and " !" or "")) or "—"
				if reset then
					detail = detail .. " · " .. (reset <= os.time() and "reset passed" or os.date("%a %d %b %H:%M", reset))
				end
				row(window.label, detail, tint(available, provider.color))
				count = count + 1
			end
		end
		if count == 0 then
			row("Quota unavailable", nil, colors.overlay2, 12)
		end
		if failure then
			row(failure, nil, colors.yellow, 11)
		elseif stale then
			row("Stale · " .. os.date("%a %d %b %H:%M", math.floor(data.updated_at)), nil, colors.yellow, 11)
		end
	end
	owner:set({ popup = { drawing = opened } })
end

local function update(cached)
	if pending then
		return
	end
	pending = true
	sbar.exec(command .. (cached and " --cached" or ""), function(data, exit_code)
		pending = false
		if exit_code == 0 and type(data) == "table" then
			snapshot = data
			read_error = nil
		else
			read_error = "Quota check failed"
		end
		render()
		if cached then
			update(false)
		end
	end)
end

for _, provider in ipairs(providers) do
	items[provider.id]:subscribe("mouse.clicked", function()
		opened = not opened
		if opened then
			render()
			update(false)
		end
		owner:set({ popup = { drawing = opened } })
	end)
end
owner:subscribe({ "front_app_switched", "mouse.exited.global" }, function()
	opened = false
	owner:set({ popup = { drawing = false } })
end)
owner:subscribe({ "routine", "forced", "system_woke" }, function() update(false) end)
update(true)

return names
