#!/usr/bin/env zsh
# SPDX-License-Identifier: ISC

_mrgsh_path_prepend() {
	local dir
	for dir in "$@"; do
		[[ -d "$dir" ]] && path=("$dir" $path)
	done
}

_mrgsh_compose_path() {
	_mrgsh_path_prepend \
		"$HOMEBREW_PREFIX/sbin" \
		"$HOMEBREW_PREFIX/bin" \
		"$GOPATH/bin" \
		"$HOME/.cargo/bin" \
		"$HOME/.local/bin" \
		"$HOME/.bin"
	typeset -gU PATH path
	export PATH
}
