require("full-border"):setup {
	type = ui.Border.ROUNDED,
}

require("git"):setup {
	order = 1500,
}

th.git = th.git or {}
th.git.clean_sign = "  "

require("relative-motions"):setup {
	show_numbers = "relative",
	show_motion = true,
}


require("folder-rules"):setup()
