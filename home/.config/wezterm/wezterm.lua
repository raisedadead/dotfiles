local wezterm = require("wezterm")

local config = {
	set_environment_variables = {
		TERM = "xterm-256color",
		LC_ALL = "en_US.UTF-8",
	},

	default_cwd = wezterm.home_dir .. "/DEV",

	audible_bell = "Disabled",

	font = wezterm.font_with_fallback({
		{ family = "Maple Mono NF", weight = "Bold" },
		{ family = "JetBrains Mono", weight = "Bold" },
	}),
	font_size = 14.0,
	color_scheme = "Catppuccin Mocha",

	initial_rows = 45,
	initial_cols = 175,

	hide_tab_bar_if_only_one_tab = true,
	use_fancy_tab_bar = false,
	window_close_confirmation = "NeverPrompt",
	window_decorations = "RESIZE",
	window_padding = {
		left = 15,
		right = 15,
		top = 10,
		bottom = 15,
	},
	window_background_opacity = 0.85,
	macos_window_background_blur = 20,

	mouse_bindings = {
		-- Ctrl/Cmd-click will open the link under the mouse cursor
		{
			event = { Up = { streak = 1, button = "Left" } },
			mods = "CMD",
			action = wezterm.action.OpenLinkAtMouseCursor,
		},
		{
			event = { Up = { streak = 1, button = "Left" } },
			mods = "CTRL",
			action = wezterm.action.OpenLinkAtMouseCursor,
		},
	},
}

return config
