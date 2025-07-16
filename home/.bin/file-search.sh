#!/usr/bin/env zsh

# Functions adapted from https://github.com/ppcamp/zsh-fzf-rg/blob/main/functions.sh

# search folder
function _mrgsh_fdd() {
	local dependencies=("fd")
	_mrgsh_check_tools "${dependencies[@]}" || return 1

	if [ ! "$#" -gt 0 ]; then
		echo "Error: Need a string to search for!"
		return 1
	fi

	fd -td $*
}

# search file
function _mrgsh_fdf() {
	local dependencies=("fd")
	_mrgsh_check_tools "${dependencies[@]}" || return 1

	if [ ! "$#" -gt 0 ]; then
		echo "Error: Need a string to search for!"
		return 1
	fi

	fd -tf $*
}

# show processes
function _mrgsh_psf() {
	local dependencies=("fzf" "ps")
	_mrgsh_check_tools "${dependencies[@]}" || return 1

	ps -ef |
		fzf --bind 'ctrl-r:reload(ps -ef)' \
			--header 'Press CTRL-R to reload' --header-lines=1 \
			--height 90% \
			--border \
			--border-label=' 💽 Find processes ' \
			--border-label-pos=2 \
			--height=50% --layout=reverse
}

# search content of files with ripgrep
function _mrgsh_rgfzf() {
	local dependencies=("rg" "fzf" "bat" "awk")
	_mrgsh_check_tools "${dependencies[@]}" || return 1

	if [ ! "$#" -gt 0 ]; then
		echo "Error: Need a string to search for!"
		return 1
	fi

	local result=$(rg --color=always --line-number --no-heading --smart-case "${*:-}" |
		fzf -d':' --ansi \
			--height 90% \
			--border \
			--border-label=' 🔍 Find string ' \
			--border-label-pos=2 \
			--preview "bat -p --color=always {1} --highlight-line {2}" \
			--preview-window ~8,+{2}-5)

	# Exit if nothing selected
	[[ -z $result ]] && return 1

	local editor="${EDITOR:-nvim}"

	# Extract filename and line number
	file=$(echo "$result" | awk -F':' '{ print $1 }')
	line=$(echo "$result" | awk -F':' '{ print $2 }')

	# Launch editor depending on what's set
	if [[ $EDITOR == *"code"* ]]; then
		code -g "$file:$line"
	else
		$editor "$file" +$line
	fi
}

# advanced search with dual modes (ripgrep/fzf)
function _mrgsh_fif() {
	local dependencies=("rg" "fzf" "bat" "awk")
	_mrgsh_check_tools "${dependencies[@]}" || return 1

	# Switch between Ripgrep launcher mode (CTRL-R) and fzf filtering mode (CTRL-F)
	rm -f /tmp/rg-fzf-{r,f}
	local RG_PREFIX="rg --column --line-number --no-heading --color=always --smart-case "
	local INITIAL_QUERY="${*:-}"

	if [[ -z "$INITIAL_QUERY" ]]; then
		INITIAL_QUERY=$LBUFFER
	fi

	# Just clear the previous line, "moving" it to the fzf prompt
	zle -I          # Clears any pending input/output
	BUFFER=""       # Clears the line buffer
	zle accept-line # Refresh/remove line buffer (previous data)

	local result=$(fzf \
		--height 90% \
		--border \
		--border-label=' 🔍 Find text ' \
		--border-label-pos=2 \
		--ansi --disabled --query "$INITIAL_QUERY" \
		--bind "start:reload($RG_PREFIX {q})+unbind(ctrl-r)" \
		--bind "change:reload:sleep 0.1; $RG_PREFIX {q} || true" \
		--bind "ctrl-f:unbind(change,ctrl-f)+change-border-label( 📂 Search in current files )+change-prompt(2. fzf> )+enable-search+rebind(ctrl-r)+transform-query(echo {q} > /tmp/rg-fzf-r; cat /tmp/rg-fzf-f)" \
		--bind "ctrl-r:unbind(ctrl-r)+change-border-label( 🔍 Find text )+change-prompt(1. ripgrep> )+disable-search+reload($RG_PREFIX {q} || true)+rebind(change,ctrl-f)+transform-query(echo {q} > /tmp/rg-fzf-f; cat /tmp/rg-fzf-r)" \
		--color "hl:-1:underline,hl+:-1:underline:reverse" \
		--prompt '1. ripgrep> ' \
		--delimiter : \
		--header '╱ CTRL-R (ripgrep mode) ╱ CTRL-F (fzf mode) ╱' \
		--preview 'bat --color=always {1} --highlight-line {2}' \
		--preview-window 'up,60%,border-bottom,+{2}+3/3,~3')

	# Exit if nothing selected or interrupted
	if [[ -z "$result" ]]; then
		zle reset-prompt 2>/dev/null || true
		return 1
	fi

	local editor="${EDITOR:-nvim}"

	# Extract filename and line number
	file=$(echo "$result" | awk -F':' '{ print $1 }')
	line=$(echo "$result" | awk -F':' '{ print $2 }')

	# Launch editor depending on what's set
	if [[ $EDITOR == *"code"* ]]; then
		code -g "$file:$line"
	else
		$editor "$file" +$line
	fi
}
