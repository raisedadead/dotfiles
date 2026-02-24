require("full-border"):setup {
	type = ui.Border.ROUNDED,
}

require("mime-ext.local"):setup {
	with_files = {
		dockerfile = "text/plain",
		containerfile = "text/plain",
		makefile = "text/plain",
		justfile = "text/plain",
		vagrantfile = "text/plain",
		gemfile = "text/plain",
		procfile = "text/plain",
		brewfile = "text/plain",
	},
}

require("git"):setup {
	order = 1500,
}

require("copy-file-contents"):setup {
	append_char = "\n",
	notification = true,
}
