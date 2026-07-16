local colors = require("colors")
local icons = require("icons")

local home = os.getenv("HOME")
local cal_bin = home .. "/.config/sketchybar/bin/calendar_events.app/Contents/MacOS/calendar_events"

local clock = sbar.add("item", "clock", {
	position = "right",
	update_freq = 10,
	icon = { string = icons.clock, color = colors.sapphire, font = { size = 13.0 } },
	label = { font = { size = 12.0, features = "tnum" } },
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

clock:subscribe({ "routine", "forced", "system_woke" }, function()
	clock:set({ label = { string = os.date("%a %d %b  %H:%M") } })
end)

local function agenda_row(i, icon_color, text, label_color)
	sbar.add("item", "clock.agenda." .. i, {
		position = "popup.clock",
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

clock:subscribe("mouse.clicked", function()
	sbar.remove("/clock\\.agenda\\..*/")
	sbar.exec("timeout 8 " .. cal_bin .. " 2>/dev/null", function(out)
		local i = 0
		for line in tostring(out or ""):gmatch("[^\r\n]+") do
			agenda_row(i, colors.peach, line, colors.text)
			i = i + 1
		end
		if i == 0 then
			agenda_row(0, colors.overlay0, "No events today", colors.overlay2)
		end
		clock:set({ popup = { drawing = "toggle" } })
	end)
end)

local calendar = sbar.add("item", "calendar", {
	position = "right",
	update_freq = 120,
	icon = { string = icons.calendar, color = colors.peach, font = { size = 13.0 } },
	label = { font = { size = 12.0 } },
})

calendar:subscribe({ "routine", "forced", "system_woke" }, function()
	sbar.exec("timeout 8 " .. cal_bin .. " --next 2>/dev/null", function(out)
		local next_event = tostring(out or ""):match("[^\r\n]+") or ""
		next_event = next_event:sub(1, 30)
		if next_event == "" then
			next_event = "No events"
		end
		calendar:set({ label = { string = next_event } })
	end)
end)

local weather = sbar.add("item", "weather", {
	position = "right",
	update_freq = 900,
	icon = { string = icons.weather, color = colors.sky, font = { size = 13.0 } },
	label = { font = { size = 12.0 } },
})

weather:subscribe({ "routine", "forced", "system_woke" }, function()
	sbar.exec("curl -sf --max-time 5 'https://wttr.in/?format=%t'", function(out)
		local reading = tostring(out or ""):gsub("+", ""):match("^%s*(.-)%s*$") or ""
		weather:set({ label = { string = reading ~= "" and reading or "--" } })
	end)
end)

local tailscale = sbar.add("item", "tailscale", {
	position = "right",
	update_freq = 15,
	icon = { string = icons.net, color = colors.green, font = { size = 13.0 } },
	label = { font = { size = 12.0 } },
})

tailscale:subscribe({ "routine", "forced", "system_woke" }, function()
	sbar.exec("/Applications/Tailscale.app/Contents/MacOS/Tailscale status --json 2>/dev/null", function(out)
		local state = type(out) == "table" and out.BackendState or "Unknown"
		if state == "Running" then
			local exit_node
			for _, peer in pairs(out.Peer or {}) do
				if peer.ExitNode and peer.DNSName then
					exit_node = peer.DNSName:match("^[^.]+")
					break
				end
			end
			if exit_node then
				tailscale:set({ icon = { color = colors.mauve }, label = { string = exit_node } })
			else
				tailscale:set({ icon = { color = colors.green }, label = { string = "on" } })
			end
		elseif state == "Stopped" or state == "NeedsLogin" or state == "NoState" or state == "Unknown" then
			tailscale:set({ icon = { color = colors.overlay0 }, label = { string = "off" } })
		else
			tailscale:set({ icon = { color = colors.yellow }, label = { string = tostring(state) } })
		end
	end)
end)

local cpu = sbar.add("item", "cpu", {
	position = "right",
	update_freq = 5,
	icon = { string = icons.cpu, color = colors.green, font = { size = 13.0 } },
	label = { font = { size = 12.0 } },
})

local ncpu = 1
sbar.exec("sysctl -n hw.ncpu", function(out)
	ncpu = tonumber(tostring(out):match("%d+")) or 1
end)

cpu:subscribe({ "routine", "forced" }, function()
	sbar.exec("ps -A -o %cpu", function(out)
		local total = 0
		for v in tostring(out or ""):gmatch("(%d+[%.,]?%d*)") do
			total = total + (tonumber((v:gsub(",", "."))) or 0)
		end
		local pct = math.floor(total / ncpu + 0.5)
		local col = colors.green
		if pct >= 80 then
			col = colors.red
		elseif pct >= 50 then
			col = colors.yellow
		end
		cpu:set({ icon = { color = col }, label = { string = pct .. "%" } })
	end)
end)

sbar.add("bracket", "status", { "cpu", "tailscale", "weather", "calendar", "clock" }, {
	background = { color = colors.surface0, corner_radius = 8, height = 28 },
})
