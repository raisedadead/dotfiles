require("full-border"):setup {
	type = ui.Border.ROUNDED,
}

th.git = th.git or {}
th.git.modified_sign = "▎"
th.git.added_sign    = "▎"
th.git.deleted_sign  = "▎"
th.git.updated_sign  = "▎"
th.git.untracked_sign = "▎"
th.git.ignored_sign  = " "
th.git.clean_sign    = " "

require("git"):setup {
	order = 1500,
}

require("relative-motions"):setup {
	show_numbers = "relative",
	show_motion = true,
}

local orig_number = Entity.number
Entity.number = function(self, index, total, file, hovered)
	local span = orig_number(self, index, total, file, hovered)
	span = span:fg("#585b70")
	return span
end

require("folder-rules"):setup()
