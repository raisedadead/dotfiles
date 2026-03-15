#!/usr/bin/env zsh

# ssh host selection
function _mrgsh_ssh() {
	local dependencies=("fzf" "grep" "cut")
	_mrgsh_check_tools "${dependencies[@]}" || return 1

	local query="${1:-}"
	grep -h "Host " ~/.ssh/config_* | grep -v '*' | cut -b 6- | fzf --query "$query" --prompt="SSH Remote > "
}

# remove from known_hosts
function _mrgsh_rkh() {
	local dependencies=("fzf" "awk" "sed" "sort" "uniq" "ssh-keygen")
	_mrgsh_check_tools "${dependencies[@]}" || return 1

	local query="${1:-}"
	local known_hosts_file="$HOME/.ssh/known_hosts"

	# Ensure known_hosts file exists
	if [[ ! -f $known_hosts_file ]]; then
		echo "Error: known_hosts file does not exist."
		return 1
	fi

	# Extract the hostnames from the known_hosts file
	local hostnames=($(awk '{print $1}' $known_hosts_file | sed 's/,/\n/g' | sort | uniq))

	# Use 'fzf' to create an interactive menu to select hostnames
	local selected_hostnames=($(printf '%s\n' "${hostnames[@]}" | fzf --multi --prompt="Remove Host > " --query "$query"))

	# If any selections were made, remove them
	if [[ ${#selected_hostnames[@]} -ne 0 ]]; then
		for sel in "${selected_hostnames[@]}"; do
			# Remove host entry using ssh-keygen
			ssh-keygen -R "$sel" >/dev/null 2>&1
			if [[ $? -eq 0 ]]; then
				echo "Removed host: $sel"
			else
				echo "Failed to remove host: $sel"
			fi
		done
	else
		echo "No host selected."
		return 1
	fi

	# Clean up
	rm -f ~/.ssh/known_hosts.old
}
