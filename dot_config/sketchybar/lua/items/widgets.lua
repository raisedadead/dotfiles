local colors = require("colors")
local icons = require("icons")

local home = os.getenv("HOME")
local cal_app = home .. "/.config/sketchybar/bin/calendar_events.app"

local function cal_cmd(args)
	return 'f=$(mktemp); /usr/bin/open -W --stdout "$f" ' .. cal_app .. (args or "") .. '; cat "$f"; rm -f "$f"'
end

local clock = sbar.add("item", "clock", {
	position = "right",
	update_freq = 10,
	icon = { string = icons.clock, color = colors.sapphire, font = { size = 13.0 } },
	label = { font = { size = 12.0, features = "tnum" } },
})

clock:subscribe({ "routine", "forced", "system_woke" }, function()
	clock:set({ label = { string = os.date("%a %d %b  %H:%M") } })
end)

local battery = sbar.add("item", "battery", {
	position = "right",
	update_freq = 120,
	icon = { color = colors.green, font = { size = 13.0 } },
	label = { font = { size = 12.0 } },
})

local function battery_icon(pct)
	if pct >= 90 then
		return icons.bat_full
	elseif pct >= 60 then
		return icons.bat_75
	elseif pct >= 35 then
		return icons.bat_50
	elseif pct >= 15 then
		return icons.bat_25
	end
	return icons.bat_empty
end

battery:subscribe({ "routine", "forced", "power_source_change", "system_woke" }, function()
	sbar.exec("pmset -g batt", function(out)
		local s = tostring(out or "")
		local pct = tonumber(s:match("(%d+)%%")) or 0
		local charging = s:find("AC Power") ~= nil
		local icon = charging and icons.bolt or battery_icon(pct)
		local col = colors.green
		if not charging then
			if pct <= 15 then
				col = colors.red
			elseif pct <= 30 then
				col = colors.yellow
			else
				col = colors.text
			end
		end
		battery:set({ icon = { string = icon, color = col }, label = { string = pct .. "%" } })
	end)
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
	update_freq = 60,
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

local net = sbar.add("item", "net", {
	position = "right",
	updates = "on",
	icon = { string = icons.speed, color = colors.sky, font = { size = 13.0 } },
	label = { font = { size = 12.0, features = "tnum" } },
})

net:subscribe("system_stats", function(env)
	local mbps = tonumber(env.NET_LINK) or 0
	local label
	if mbps >= 1000 then
		label = string.format("%.1fG", mbps / 1000)
	elseif mbps > 0 then
		label = mbps .. "M"
	else
		label = "—"
	end
	net:set({
		icon = { color = mbps > 0 and colors.sky or colors.overlay0 },
		label = { string = label },
	})
end)

local mem = sbar.add("item", "mem", {
	position = "right",
	updates = "on",
	icon = { string = icons.mem, color = colors.teal, font = { size = 13.0 } },
	label = { font = { size = 12.0 } },
})

mem:subscribe("system_stats", function(env)
	local pct = tonumber(env.MEM) or 0
	local col = colors.teal
	if pct >= 85 then
		col = colors.red
	elseif pct >= 70 then
		col = colors.yellow
	end
	mem:set({ icon = { color = col }, label = { string = pct .. "%" } })
end)

local cpu = sbar.add("item", "cpu", {
	position = "right",
	updates = "on",
	icon = { string = icons.cpu, color = colors.green, font = { size = 13.0 } },
	label = { font = { size = 12.0 } },
})

cpu:subscribe("system_stats", function(env)
	local pct = tonumber(env.CPU) or 0
	local col = colors.green
	if pct >= 80 then
		col = colors.red
	elseif pct >= 50 then
		col = colors.yellow
	end
	cpu:set({ icon = { color = col }, label = { string = pct .. "%" } })
end)

sbar.add("bracket", "status", { "cpu", "mem", "net", "tailscale", "calendar", "battery", "clock" }, {
	background = {
		color = colors.island,
		corner_radius = 12,
		height = 32,
		border_width = 1,
		border_color = colors.island_border,
	},
})
