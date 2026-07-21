local colors = require("colors")
local icons = require("icons")

local home = os.getenv("HOME")
local cal_app = home .. "/.config/sketchybar/bin/calendar_events.app"

local function cal_cmd(args)
	return 'f=$(mktemp); /usr/bin/open -W --stdout "$f" ' .. cal_app .. (args or "") .. '; cat "$f"; rm -f "$f"'
end

local clock = sbar.add("item", "clock", {
	position = "right",
	update_freq = 30,
	icon = { string = icons.clock, color = colors.sapphire, font = { size = 13.0 } },
	label = { font = { size = 12.0, features = "tnum" } },
})

clock:subscribe({ "routine", "forced", "system_woke" }, function()
	clock:set({ label = { string = os.date("%a %d %b  %H:%M") } })
end)

local function agenda_row(i, icon_color, text, label_color)
	sbar.add("item", "calendar.agenda." .. i, {
		position = "popup.calendar",
		icon = {
			string = icons.calendar,
			color = icon_color,
			font = { family = colors.icon_font, style = "Regular", size = 11.0 },
			padding_left = 10,
			padding_right = 6,
		},
		label = {
			string = text,
			font = { family = colors.font, style = "Regular", size = 12.0 },
			color = label_color,
			max_chars = 36,
			padding_right = 12,
		},
		background = { drawing = "off" },
	})
end

local calendar = sbar.add("item", "calendar", {
	position = "right",
	update_freq = 300,
	icon = { string = icons.calendar, color = colors.peach, font = { size = 13.0 } },
	label = { font = { size = 12.0 } },
	popup = {
		background = {
			color = colors.surface0,
			corner_radius = 8,
			border_width = 2,
			border_color = colors.surface2,
		},
		horizontal = "off",
		align = "right",
		y_offset = 2,
	},
})

calendar:subscribe({ "routine", "forced", "system_woke" }, function()
	sbar.exec(cal_cmd(" --args --next"), function(out)
		local next_event = tostring(out or ""):match("[^\r\n]+") or ""
		next_event = next_event:sub(1, 30)
		if next_event == "" then
			next_event = "No events"
		end
		calendar:set({ label = { string = next_event } })
	end)
end)

calendar:subscribe("mouse.clicked", function()
	sbar.remove("/calendar\\.agenda\\..*/")
	sbar.exec(cal_cmd(), function(out)
		local i = 0
		for line in tostring(out or ""):gmatch("[^\r\n]+") do
			agenda_row(i, colors.peach, line, colors.text)
			i = i + 1
		end
		if i == 0 then
			agenda_row(0, colors.overlay0, "No events today", colors.overlay2)
		end
		calendar:set({ popup = { drawing = "toggle" } })
	end)
end)

local tailscale = sbar.add("item", "tailscale", {
	position = "right",
	update_freq = 180,
	icon = { string = icons.app("Tailscale"), color = colors.green, font = { family = colors.app_font, style = "Regular", size = 16.0 } },
	label = { font = { size = 12.0 }, max_chars = 28 },
})

local function tailscale_refresh()
	sbar.exec("/Applications/Tailscale.app/Contents/MacOS/Tailscale status --json 2>/dev/null", function(out)
		local state = type(out) == "table" and out.BackendState or "Unknown"
		if state == "Running" then
			local login
			local uid = out.Self and out.Self.UserID
			if uid then
				local u = (out.User or {})[string.format("%.0f", uid)]
				login = u and u.LoginName
			end
			if not login then
				login = out.CurrentTailnet and out.CurrentTailnet.Name or "on"
			end
			local exit_node
			for _, peer in pairs(out.Peer or {}) do
				if peer.ExitNode and peer.DNSName then
					exit_node = peer.DNSName:match("^[^.]+"):gsub("^exit%-node%-", "")
					break
				end
			end
			if exit_node then
				tailscale:set({ icon = { color = colors.mauve }, label = { string = login .. " → " .. exit_node } })
			else
				tailscale:set({ icon = { color = colors.green }, label = { string = login } })
			end
		else
			tailscale:set({ icon = { color = colors.overlay0 }, label = { string = "Disconnected" } })
		end
	end)
end

tailscale:subscribe({ "routine", "forced", "system_woke" }, tailscale_refresh)
tailscale:subscribe("mouse.clicked", tailscale_refresh)

sbar.add("bracket", "status", { "tailscale", "calendar", "clock" }, {
	background = {
		color = colors.island,
		corner_radius = 12,
		height = 32,
		border_width = 1,
		border_color = colors.island_border,
	},
})
