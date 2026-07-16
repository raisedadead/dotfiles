local colors = require("colors")
local icons = require("icons")

local aerospace = "/opt/homebrew/bin/aerospace"
local workspaces = { "1", "2", "3", "4", "5", "6" }
local persistent = { ["1"] = true, ["2"] = true, ["3"] = true, ["4"] = true }
local focused = ""
local spaces = {}

local function style(space, sid, strip, n)
	if sid == focused then
		space:set({
			drawing = "on",
			background = { drawing = "on" },
			icon = { color = colors.crust },
			label = { string = strip, color = colors.crust },
		})
	else
		local draw = n > 0 and "on" or "off"
		space:set({
			drawing = draw,
			background = { drawing = "off" },
			icon = { color = colors.overlay2 },
			label = { string = strip, color = colors.overlay2 },
		})
	end
end

local function refresh(space, sid)
	sbar.exec(aerospace .. " list-windows --workspace " .. sid .. " --format '%{app-name}'", function(out)
		local strip = ""
		local n = 0
		for app in tostring(out or ""):gmatch("[^\r\n]+") do
			strip = strip .. icons.app(app) .. " "
			n = n + 1
		end
		style(space, sid, strip, n)
	end)
end

for _, sid in ipairs(workspaces) do
	local space = sbar.add("item", "space." .. sid, {
		position = "left",
		drawing = persistent[sid] and "on" or "off",
		updates = "on",
		update_freq = 10,
		icon = {
			string = sid,
			font = { family = colors.font, style = "Bold", size = 14.0 },
			color = colors.overlay2,
			padding_left = 9,
			padding_right = 4,
		},
		label = {
			font = { family = colors.app_font, style = "Regular", size = 14.0 },
			color = colors.overlay2,
			padding_left = 0,
			padding_right = 9,
		},
		background = { color = colors.mauve, corner_radius = 6, height = 24, drawing = "off" },
		click_script = aerospace .. " workspace " .. sid,
	})
	spaces[sid] = space

	space:subscribe("aerospace_workspace_change", function(env)
		focused = env.FOCUSED_WORKSPACE
		refresh(space, sid)
	end)

	space:subscribe({ "routine", "front_app_switched", "system_woke" }, function()
		refresh(space, sid)
	end)
end

sbar.exec(aerospace .. " list-workspaces --focused", function(out)
	focused = tostring(out or ""):match("%S+") or ""
	for sid, space in pairs(spaces) do
		refresh(space, sid)
	end
end)
