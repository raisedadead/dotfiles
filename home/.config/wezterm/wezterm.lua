local wezterm = require("wezterm")

local config = {
	set_environment_variables = {
		TERM = "xterm-256color",
		LC_ALL = "en_US.UTF-8",
	},

	default_cwd = wezterm.home_dir .. "/DEV",

	use_fancy_tab_bar = false,

	audible_bell = "Disabled",

	font = wezterm.font_with_fallback({
		{ family = "Maple Mono NF", weight = "Regular" },
		{ family = "JetBrains Mono", weight = "Bold" },
	}),
	font_size = 14.0,

	color_scheme = "Catppuccin Mocha",

	initial_rows = 45,
	initial_cols = 175,

	hide_tab_bar_if_only_one_tab = true,

	window_close_confirmation = "NeverPrompt",
	window_decorations = "RESIZE",
	window_padding = {
		left = 15,
		right = 15,
		top = 10,
		bottom = 15,
	},
	window_background_opacity = 0.8,
	macos_window_background_blur = 20,
}

return config
