require("full-border"):setup {
	type = ui.Border.ROUNDED,
}

require("git"):setup {
	order = 1500,
}

require("copy-file-contents"):setup {
	append_char = "\n",
	notification = true,
}

require("yamb"):setup {
	cli = "fzf",
	jump_notify = true,
}
