local colors = require("colors")
local icons = require("icons")
local separator = require("separator")

local media_control = "/opt/homebrew/bin/media-control"
local players = {
	["com.spotify.client"] = { name = "Spotify", color = colors.green },
	["com.apple.Music"] = { name = "Music", color = colors.red },
}
local bundle

sbar.add("event", "spotify_change", "com.spotify.client.PlaybackStateChanged")
sbar.add("event", "music_change", "com.apple.Music.playerInfo")

local divider = separator("now_playing.separator", "center", { drawing = "off" })

local now_playing = sbar.add("item", "now_playing", {
	position = "center",
	drawing = "off",
	updates = "on",
	icon = {
		font = { family = colors.app_font, style = "Regular", size = 17.0 },
	},
	label = { max_chars = 48, font = { size = 13.0 } },
})

local function render(bundle_id, playing, artist, title)
	local player = playing and type(title) == "string" and title ~= "" and players[bundle_id]
	bundle = player and bundle_id
	divider:set({ drawing = player and "on" or "off" })
	if not player then
		now_playing:set({ drawing = "off" })
		return
	end
	now_playing:set({
		drawing = "on",
		icon = { string = icons.app(player.name), color = player.color },
		label = { string = type(artist) == "string" and artist ~= "" and (artist .. " — " .. title) or title },
	})
end

local function update()
	sbar.exec(media_control .. " get --no-artwork", function(info)
		if type(info) == "table" then
			render(info.bundleIdentifier, info.playing, info.artist, info.title)
		else
			render()
		end
	end)
end

local function notified(bundle_id)
	return function(env)
		local info = type(env.INFO) == "table" and env.INFO or {}
		if info["Player State"] == "Playing" then
			render(bundle_id, true, info.Artist, info.Name)
		else
			update()
		end
	end
end

now_playing:subscribe("spotify_change", notified("com.spotify.client"))
now_playing:subscribe("music_change", notified("com.apple.Music"))
now_playing:subscribe({ "forced", "system_woke" }, update)
now_playing:subscribe("mouse.clicked", function()
	if bundle then
		sbar.exec("/usr/bin/open -b " .. bundle)
	end
end)
update()

return { "now_playing.separator", "now_playing" }
