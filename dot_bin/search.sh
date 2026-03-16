#!/usr/bin/env zsh

# search file contents via tv text channel (opens in $EDITOR at match line)
function _mrgsh_sg() {
	local dependencies=("tv")
	_mrgsh_check_tools "${dependencies[@]}" || return 1

	if [[ $# -eq 0 ]]; then
		tv text
	else
		tv text -i "$*"
	fi
}

# search filenames via tv files channel (opens in $EDITOR)
function _mrgsh_sf() {
	local dependencies=("tv")
	_mrgsh_check_tools "${dependencies[@]}" || return 1

	if [[ $# -eq 0 ]]; then
		tv files
	else
		tv files -i "$*"
	fi
}
