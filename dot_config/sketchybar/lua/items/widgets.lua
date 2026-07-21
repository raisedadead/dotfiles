local colors = require("colors")
local icons = require("icons")

local clock = sbar.add("item", "clock", {
	position = "right",
	update_freq = 30,
	icon = { string = icons.clock, color = colors.sapphire, font = { size = 13.0 } },
	label = { font = { size = 12.0, features = "tnum" } },
})

clock:subscribe({ "routine", "forced", "system_woke" }, function()
	clock:set({ label = { string = os.date("%a %d %b  %H:%M") } })
end)

local utc_clock = sbar.add("item", "utc_clock", {
	position = "right",
	update_freq = 30,
	icon = { string = icons.utc, color = colors.teal, font = { size = 13.0 } },
	label = { font = { size = 12.0, features = "tnum" } },
})

utc_clock:subscribe({ "routine", "forced", "system_woke" }, function()
	utc_clock:set({ label = { string = "UTC " .. os.date("!%H:%M") } })
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

sbar.add("bracket", "status", { "tailscale", "utc_clock", "clock" }, {
	background = {
		color = colors.island,
		corner_radius = 12,
		height = 32,
		border_width = 1,
		border_color = colors.island_border,
	},
})
