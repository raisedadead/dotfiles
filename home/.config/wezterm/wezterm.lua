local wezterm = require("wezterm")
local balance = require("balance")
local config = {
	set_environment_variables = {
		TERM = "xterm-256color",
		LC_ALL = "en_US.UTF-8",
	},

	default_cwd = wezterm.home_dir .. "/DEV",

	audible_bell = "Disabled",

	font = wezterm.font_with_fallback({
		{ family = "Maple Mono" },
		{ family = "JetBrainsMono Nerd Font" },
		{ family = "Symbols Nerd Font Mono" },
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
		top = 25,
		bottom = 15,
	},
	window_background_opacity = 0.9,
	macos_window_background_blur = 40,


	mouse_bindings = {
		-- Ctrl/Cmd-click will open the link under the mouse cursor
		{
			event = { Up = { streak = 1, button = "Left" } },
			mods = "OPT",
			action = wezterm.action.OpenLinkAtMouseCursor,
		},
		{
			event = { Up = { streak = 1, button = "Left" } },
			mods = "CTRL",
			action = wezterm.action.OpenLinkAtMouseCursor,
		},
	},

	keys = {
		-- Open WezTerm Config
		{
			key = ",",
			mods = "CMD",
			action = wezterm.action.SpawnCommandInNewTab({
				cwd = os.getenv("WEZTERM_CONFIG_DIR"),
				set_environment_variables = {
					TERM = "screen-256color",
				},
				args = {
					"vi",
					os.getenv("WEZTERM_CONFIG_FILE"),
				},
			}),
		},
		-- Tab Navigator
		{
			key = "t",
			mods = "CMD|SHIFT",
			action = wezterm.action.ShowTabNavigator,
		},
		-- Panes
		-- Split pane horizontally
		{
			key = "d",
			mods = "CMD",
			action = wezterm.action({ SplitHorizontal = { domain = "CurrentPaneDomain" } }),
		},
		-- Split pane vertically
		{
			key = "d",
			mods = "CMD|SHIFT",
			action = wezterm.action({ SplitVertical = { domain = "CurrentPaneDomain" } }),
		},
		-- Balance Panes
		{
			key = 'b',
			mods = 'CMD',
			action = wezterm.action.Multiple {
				wezterm.action_callback(balance.balance_panes("x")),
				wezterm.action_callback(balance.balance_panes("y")),
			},
		},
		-- Zoom and Close
		{ key = "z", mods = "CMD", action = "TogglePaneZoomState" },
		{ key = "x", mods = "CMD", action = wezterm.action({ CloseCurrentPane = { confirm = true } }) },
		-- Navigate Panes
		{ key = "h", mods = "CMD", action = wezterm.action({ ActivatePaneDirection = "Left" }) },
		{ key = "LeftArrow", mods = "CMD", action = wezterm.action({ ActivatePaneDirection = "Left" }) },
		{ key = "j", mods = "CMD", action = wezterm.action({ ActivatePaneDirection = "Down" }) },
		{ key = "DownArrow", mods = "CMD", action = wezterm.action({ ActivatePaneDirection = "Down" }) },
		{ key = "k", mods = "CMD", action = wezterm.action({ ActivatePaneDirection = "Up" }) },
		{ key = "UpArrow", mods = "CMD", action = wezterm.action({ ActivatePaneDirection = "Up" }) },
		{ key = "l", mods = "CMD", action = wezterm.action({ ActivatePaneDirection = "Right" }) },
		{ key = "RightArrow", mods = "CMD", action = wezterm.action({ ActivatePaneDirection = "Right" }) },
	},
}

return config
