#!/usr/bin/env zsh
# SPDX-License-Identifier: ISC

function _mrgsh_fnm_vers() {
	fnm list | awk '$2 ~ /^v/ {print $2}'
}

function _mrgsh_node_globals() {
	local dependencies=("fnm" "npm" "jq" "gum")
	_mrgsh_check_tools "${dependencies[@]}" || return 1

	local from="${1:-$(_mrgsh_fnm_vers | gum choose --header 'globals FROM which version?')}"
	[[ -n "$from" ]] || return 1

	local pkgs
	pkgs=("${(@f)$(fnm exec --using="$from" npm ls -g --depth=0 --json 2>/dev/null |
		jq -r '.dependencies | keys_unsorted[] | select(. != "npm" and . != "corepack")' |
		gum choose --no-limit --header "reinstall on $(node -v):")}")

	((${#pkgs})) || {
		printf '%s\n' "Nothing selected."
		return 0
	}
	npm install -g -- "${pkgs[@]}"
}

function _mrgsh_fnm_rm() {
	local dependencies=("fnm" "gum")
	_mrgsh_check_tools "${dependencies[@]}" || return 1

	local current
	current="$(fnm current)"

	local versions
	versions=("${(@f)$(_mrgsh_fnm_vers | grep -vx "$current" |
		gum choose --no-limit --header 'uninstall which? (current excluded)')}")

	((${#versions})) || return 0
	gum confirm "Uninstall: ${versions[*]} ?" || return 1

	local v
	for v in "${versions[@]}"; do
		fnm uninstall "$v"
	done
}

function _mrgsh_fnm_use() {
	local dependencies=("fnm" "gum")
	_mrgsh_check_tools "${dependencies[@]}" || return 1

	local v
	v="$(_mrgsh_fnm_vers | gum choose --header 'use which version?')"
	[[ -n "$v" ]] && fnm use "$v"
}

function _mrgsh_fnm_default() {
	local dependencies=("fnm" "gum")
	_mrgsh_check_tools "${dependencies[@]}" || return 1

	local v
	v="$(_mrgsh_fnm_vers | gum choose --header 'set default to?')"
	[[ -n "$v" ]] && fnm default "$v"
}

function _mrgsh_fnm_install() {
	local dependencies=("fnm" "gum")
	_mrgsh_check_tools "${dependencies[@]}" || return 1

	local line
	line="$(fnm ls-remote --lts | gum filter --header 'install which LTS?')"
	[[ -n "$line" ]] && fnm install "${line%% *}"
}
