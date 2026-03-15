#!/usr/bin/env zsh

# search file contents, filter by filename, open in $EDITOR at match line
function _mrgsh_sg() {
	local dependencies=("rg" "fzf" "bat")
	_mrgsh_check_tools "${dependencies[@]}" || return 1

	if [[ $# -eq 0 ]]; then
		echo "Usage: rgs <pattern>" >&2
		return 1
	fi

	local pattern="$*"
	local file
	file=$(
		rg --files-with-matches --smart-case -- "$pattern" |
			fzf --preview "rg --color=always --smart-case -C 3 -- ${(q)pattern} {}" \
				--preview-window='right:60%' \
				--prompt='Filter > ' \
				--exit-0
	)

	[[ -z "$file" ]] && return 0

	local line
	line=$(rg --line-number --smart-case -- "$pattern" "$file" | head -1 | cut -d: -f1)

	if [[ $EDITOR == *"code"* ]]; then
		code -g "$file:${line:-1}"
	else
		"${EDITOR:-nvim}" "+${line:-1}" "$file"
	fi
}

# search filenames, filter results, open in $EDITOR
function _mrgsh_sf() {
	local dependencies=("fd" "fzf" "bat")
	_mrgsh_check_tools "${dependencies[@]}" || return 1

	if [[ $# -eq 0 ]]; then
		echo "Usage: fds <pattern>" >&2
		return 1
	fi

	local pattern="$*"
	local file
	file=$(
		fd --type f -- "$pattern" |
			fzf --preview 'bat --color=always {}' \
				--preview-window='right:60%' \
				--prompt='Filter > ' \
				--exit-0
	)

	[[ -z "$file" ]] && return 0

	if [[ $EDITOR == *"code"* ]]; then
		code "$file"
	else
		"${EDITOR:-nvim}" "$file"
	fi
}
