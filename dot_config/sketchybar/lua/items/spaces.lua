local colors = require("colors")
local icons = require("icons")

local aerospace = "/opt/homebrew/bin/aerospace"
local workspaces = { "1", "2", "3", "4", "5" }
local focused = ""
local spaces = {}
local separators = {}

local function style(space, sid, strip)
	if sid == focused then
		space:set({
			drawing = "on",
			background = { drawing = "on" },
			icon = { color = colors.crust },
			label = { string = strip, color = colors.crust },
		})
	else
		space:set({
			drawing = strip ~= "" and "on" or "off",
			background = { drawing = "off" },
			icon = { color = colors.overlay2 },
			label = { string = strip, color = colors.overlay2 },
		})
	end
end

local function refresh_all()
	sbar.exec(aerospace .. " list-windows --all --format '%{workspace}|%{app-name}'", function(out)
		local strips = {}
		for line in tostring(out or ""):gmatch("[^\r\n]+") do
			local ws, app = line:match("^([^|]+)|(.*)$")
			if ws and spaces[ws] then
				strips[ws] = (strips[ws] or "") .. icons.app(app) .. " "
			end
		end
		local previous_visible = false
		for _, sid in ipairs(workspaces) do
			local strip = strips[sid] or ""
			local visible = sid == focused or strip ~= ""
			style(spaces[sid], sid, strip)
			if separators[sid] then
				separators[sid]:set({ drawing = visible and previous_visible and "on" or "off" })
			end
			previous_visible = previous_visible or visible
		end
	end)
end

for index, sid in ipairs(workspaces) do
	if index > 1 then
		separators[sid] = sbar.add("item", "space.separator." .. sid, {
			position = "left",
			drawing = "off",
			width = 14,
			icon = {
				string = "│",
				font = { family = colors.font, size = 13 },
				color = colors.surface2,
				padding_left = 3,
				padding_right = 3,
			},
			label = { drawing = false },
		})
	end
	local space = sbar.add("item", "space." .. sid, {
		position = "left",
		drawing = "off",
		icon = {
			string = sid,
			font = { family = colors.font, style = "Bold", size = 15.0 },
			color = colors.overlay2,
			padding_left = 10,
			padding_right = 5,
		},
		label = {
			font = { family = colors.app_font, style = "Regular", size = 15.0 },
			color = colors.overlay2,
			padding_left = 0,
			padding_right = 10,
		},
		background = { color = colors.mauve, corner_radius = 5, height = 22, drawing = "off" },
		click_script = aerospace .. " workspace " .. sid,
	})
	spaces[sid] = space
end

local updater = sbar.add("item", "spaces_sync", {
	position = "left",
	drawing = "off",
	updates = "on",
	update_freq = 60,
})

updater:subscribe("aerospace_workspace_change", function(env)
	focused = env.FOCUSED_WORKSPACE
	refresh_all()
end)

updater:subscribe("front_app_switched", refresh_all)

updater:subscribe({ "routine", "forced", "system_woke" }, function()
	sbar.exec(aerospace .. " list-workspaces --focused", function(out)
		focused = tostring(out or ""):match("%S+") or focused
		refresh_all()
	end)
end)

sbar.exec(aerospace .. " list-workspaces --focused", function(out)
	focused = tostring(out or ""):match("%S+") or ""
	refresh_all()
end)
