#!/usr/bin/env zsh

# commit in the past
function _mrgsh_gcp() {
	local dependencies=("git" "date")
	_mrgsh_check_tools "${dependencies[@]}" || return 1

	if [ -z "$1" ]; then
		echo "Error: Please pass an argument as a number (as in days ago)."
		return 1
	fi

	local commit_target_date="undefined"
	local target=$(_mrgsh_get_system)
	case "$target" in
	macos*)
		commit_target_date=$(date -v-$1d)
		;;
	linux*)
		commit_target_date=$(date --date="$1 days ago")
		;;
	*) ;;

	esac

	if [ "$commit_target_date" != "undefined" ]; then
		GIT_COMMITTER_DATE="$commit_target_date" git commit --amend --no-edit --date "$commit_target_date"
	else
		echo "Error: Custom script failed or not implemented for your OS"
	fi
}
