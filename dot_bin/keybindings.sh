#!/usr/bin/env zsh

# Keybindings adapted from https://github.com/ppcamp/zsh-fzf-rg/blob/main/keybindings.sh

# Only register widgets and keybindings if fzf is available
if command -v yazi &>/dev/null; then
	function _yazi_widget() {
		y
		zle reset-prompt
	}
	zle -N _yazi_widget
	bindkey '^f' _yazi_widget
fi
