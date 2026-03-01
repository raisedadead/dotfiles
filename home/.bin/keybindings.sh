#!/usr/bin/env zsh

# Keybindings adapted from https://github.com/ppcamp/zsh-fzf-rg/blob/main/keybindings.sh

# Only register widgets and keybindings if fzf is available
if command -v fzf &>/dev/null; then
	# zle widget for ssh host selection
	function _mrgsh_ssh_widget() {
		local selected_host=$(_mrgsh_ssh "$LBUFFER")
		if [ -n "$selected_host" ]; then
			BUFFER="ssh ${selected_host}"
			zle accept-line
		fi
		zle reset-prompt
	}

	# register zle widgets
	zle -N _mrgsh_ssh_widget

	# zle widget for which-key
	function _mrgsh_whichkey_widget() {
		which-key
		zle reset-prompt
	}

	# register zle widgets
	zle -N _mrgsh_whichkey_widget

	# keybindings
	bindkey '^z' '_mrgsh_ssh_widget'     # bind Ctrl+Z to ssh selection
	bindkey '^_' '_mrgsh_whichkey_widget' # bind Ctrl+/ to which-key
fi
