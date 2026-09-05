local colors = require("colors")
local icons = require("icons")
local config = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local providers = {
	{ id = "claude", label = "Claude", color = colors.peach },
	{ id = "codex", label = "Codex", color = colors.teal },
}
local items, names = {}, {}
local update, close, watch
local snapshot, pending, opened = {}, false, false
local opened_until = 0
local watch_generation = 0
local renderer_ready, watching_generation = false, nil
local cache = (os.getenv("XDG_CACHE_HOME") or (os.getenv("HOME") .. "/.cache")) .. "/sketchybar-usage"
local renderer = config .. "/sketchybar/usage-panel.swift"
local binary = cache .. "/usage-panel"
local image_slot = 0
local panel_width = 480
local owner

local function quote(value)
	return "'" .. value:gsub("'", "'\\''") .. "'"
end
local command = "/opt/homebrew/bin/python3 " .. quote(config .. "/sketchybar/usage.py")

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

for i, provider in ipairs(providers) do
	local name = "usage." .. provider.id
	items[provider.id] = sbar.add("item", name, {
		position = "right",
		padding_left = 4,
		padding_right = 4,
		icon = { string = icons.app(provider.label), color = provider.color, font = { family = colors.app_font, size = 16 } },
		label = { string = "—", font = { size = 12, features = "tnum" } },
	})
	table.insert(names, name)
	if i < #providers then
		local separator = name .. ".separator"
		sbar.add("item", separator, {
			position = "right",
			width = 10,
			icon = { string = "│", font = { family = colors.font, size = 12 }, color = colors.surface2, padding_left = 2, padding_right = 2 },
			label = { drawing = false },
		})
		table.insert(names, separator)
	end
end
owner = items.claude
owner:set({
	update_freq = 60,
	popup = {
		align = "right",
		height = 1,
		y_offset = -10,
		background = { color = 0xff1a1b26, border_color = 0xff414655, border_width = 1, corner_radius = 12 },
	},
})

local panel = sbar.add("item", "usage.popup.panel", {
	position = "popup.usage.claude",
	width = panel_width,
	padding_left = 0,
	padding_right = 0,
	icon = { drawing = false },
	label = { string = "Loading quota…", width = panel_width, align = "center", padding_left = 0, padding_right = 0 },
	background = { drawing = true, color = 0x00000000, height = 80 },
})
local footer = sbar.add("item", "usage.popup.footer", {
	position = "popup.usage.claude",
	width = panel_width - 36,
	padding_left = 18,
	padding_right = 18,
	update_freq = 1,
	updates = false,
	icon = { string = "Local reset times", color = 0xffacb0c0, font = { family = colors.font, size = 11 }, width = 220, padding_left = 0, padding_right = 0 },
	label = { string = "", color = colors.text, font = { family = colors.font, size = 11 }, width = panel_width - 256, align = "right", padding_left = 0, padding_right = 0 },
	background = { drawing = true, color = 0x00000000, height = 40 },
})

local function render_footer()
	if opened and os.time() >= opened_until then
		close()
		return
	end
	local deadline
	for _, provider in ipairs(providers) do
		local next_attempt = (snapshot[provider.id] or {}).next_attempt or 0
		deadline = math.min(deadline or next_attempt, next_attempt)
	end
	local delay = math.max(0, math.ceil((deadline or 0) - os.time()))
	local duration = delay < 60 and (delay .. "s") or (math.ceil(delay / 60) .. "m")
	footer:set({ label = { string = pending and "Checking quota…" or delay > 0 and ("Next check in " .. duration .. "  ↻") or "Refresh quota  ↻" } })
end

local function render()
	for _, provider in ipairs(providers) do
		local data = snapshot[provider.id] or {}
		local value = remaining(data.weekly)
		local stale = data.error or (data.updated_at and os.time() - data.updated_at > 1800)
		items[provider.id]:set({ label = { string = (value and (value .. "%") or "—") .. (stale and " ·" or ""), color = tint(value, provider.color) } })
	end
	render_footer()
end

update = function(cached)
	if pending then
		return
	end
	pending = true
	render_footer()
	image_slot = 1 - image_slot
	local image_path = cache .. "/panel-" .. image_slot .. ".png"
	local build = "if [ ! -x " .. quote(binary) .. " ] || [ " .. quote(renderer) .. " -nt " .. quote(binary) .. " ]; then /usr/bin/xcrun swiftc -O " .. quote(renderer) .. " -o " .. quote(binary) .. "; fi"
	local script = command .. (cached and " --cached" or "") .. " && (" .. build .. ") && " .. quote(binary) .. " " .. quote(cache .. "/quota.json") .. " " .. quote(image_path)
	sbar.exec(script, function(data, exit_code)
		pending = false
		if type(data) == "table" then
			snapshot = data
		end
		if exit_code == 0 then
			renderer_ready = true
			panel:set({ label = { drawing = false }, background = { height = 0, image = { string = image_path, scale = 0.5 } } })
			if opened then
				watch()
			end
		else
			panel:set({ label = { drawing = true, string = "Quota panel unavailable" } })
		end
		render()
	end)
end

close = function()
	opened = false
	watch_generation = watch_generation + 1
	footer:set({ updates = false })
	owner:set({ popup = { drawing = false } })
end
watch = function()
	local generation = watch_generation
	if not renderer_ready or watching_generation == generation then
		return
	end
	watching_generation = generation
	sbar.exec(quote(binary) .. " --watch", function(data, exit_code)
		if watching_generation == generation then
			watching_generation = nil
		end
		if not opened or generation ~= watch_generation then
			return
		end
		if exit_code == 0 and type(data) == "table" then
			if data.outside or os.time() >= opened_until then
				close()
			else
				watch()
			end
		end
	end)
end
for _, provider in ipairs(providers) do
	items[provider.id]:subscribe("mouse.clicked", function()
		if opened then
			close()
		else
			opened = true
			opened_until = os.time() + 15
			owner:set({ popup = { drawing = true } })
			footer:set({ updates = true })
			update(false)
			watch()
		end
	end)
end
footer:subscribe("routine", render_footer)
footer:subscribe("mouse.clicked", function()
	opened_until = os.time() + 15
	update(false)
end)
owner:subscribe("front_app_switched", function()
	if opened then
		close()
	end
end)
owner:subscribe({ "routine", "forced", "system_woke" }, function() update(false) end)
update(true)

return names
