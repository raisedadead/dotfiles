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
		rakefile = "text/plain",
		guardfile = "text/plain",
		taskfile = "text/plain",
		cakefile = "text/plain",
		license = "text/plain",
		changelog = "text/plain",
		readme = "text/plain",
		authors = "text/plain",
	},
	with_exts = {
		log = "text/plain",
		conf = "text/plain",
		cfg = "text/plain",
		ini = "text/plain",
		env = "text/plain",
		service = "text/plain",
		timer = "text/plain",
		socket = "text/plain",
		plist = "text/xml",
		lock = "text/plain",
		pid = "text/plain",
		gitignore = "text/plain",
		gitconfig = "text/plain",
		gitmodules = "text/plain",
		editorconfig = "text/plain",
		dockerignore = "text/plain",
		eslintrc = "text/plain",
		prettierrc = "text/plain",
		babelrc = "text/plain",
	},
}

require("git"):setup {
	order = 1500,
}

require("copy-file-contents"):setup {
	append_char = "\n",
	notification = true,
}
