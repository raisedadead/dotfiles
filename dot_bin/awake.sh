#!/usr/bin/env zsh
# SPDX-License-Identifier: ISC

zmodload -F zsh/datetime b:strftime p:EPOCHSECONDS 2>/dev/null

_mrgsh_awake_statefile() {
	local dir="${XDG_STATE_HOME:-$HOME/.local/state}/awake"
	[[ -d "$dir" ]] || mkdir -p "$dir"
	print -r -- "$dir/session"
}

_mrgsh_awake_alive() {
	[[ -n "$1" ]] || return 1
	[[ "$(ps -p "$1" -o comm= 2>/dev/null)" == *caffeinate ]]
}

_mrgsh_awake_load() {
	local f pid deadline spec
	f="$(_mrgsh_awake_statefile)"
	[[ -r "$f" ]] || return 1
	IFS=$'\t' read -r pid deadline spec <"$f"
	if ! _mrgsh_awake_alive "$pid"; then
		rm -f -- "$f"
		return 1
	fi
	typeset -g _mrgsh_awake_pid="$pid"
	typeset -g _mrgsh_awake_deadline="$deadline"
	typeset -g _mrgsh_awake_spec="$spec"
}

_mrgsh_awake_human() {
	local total="$1" h m
	((h = total / 3600))
	((m = (total % 3600) / 60))
	if ((h > 0)); then
		print -r -- "${h}h${m}m"
	elif ((m > 0)); then
		print -r -- "${m}m"
	else
		print -r -- "${total}s"
	fi
}

_mrgsh_awake_secs() {
	local spec="$1" n
	case "$spec" in
	<->h)
		n="${spec%h}"
		if ((n < 1 || n > 24)); then
			print -ru2 -- "awake: hours must be 1-24 (got ${spec})"
			return 1
		fi
		print -r -- $((n * 3600))
		;;
	<->m)
		n="${spec%m}"
		if ((n < 1 || n > 59)); then
			print -ru2 -- "awake: minutes must be 1-59, use hours from 1h up (got ${spec})"
			return 1
		fi
		print -r -- $((n * 60))
		;;
	*)
		print -ru2 -- "awake: need a duration with a unit, 2h or 30m (got '${spec}')"
		return 1
		;;
	esac
}

_mrgsh_awake_usage() {
	print -r -- "usage: awake [Nh|Nm]   prevent sleep, default 8h"
	print -r -- "       awake off       release"
	print -r -- "       awake status    time remaining"
}

_mrgsh_awake_start() {
	local secs="$1" spec="$2" f pid deadline
	f="$(_mrgsh_awake_statefile)"

	if _mrgsh_awake_load; then
		kill "$_mrgsh_awake_pid" 2>/dev/null
		print -r -- "awake: replaced session (pid ${_mrgsh_awake_pid})"
	fi

	caffeinate -dims -t "$secs" &|
	pid=$!
	((deadline = EPOCHSECONDS + secs))
	printf '%s\t%s\t%s\n' "$pid" "$deadline" "$spec" >"$f"
	print -r -- "awake ${spec} - pid ${pid}, until $(strftime '%H:%M' "$deadline")"
}

_mrgsh_awake_status() {
	if ! _mrgsh_awake_load; then
		print -r -- "awake: not active"
		return 1
	fi
	local left
	((left = _mrgsh_awake_deadline - EPOCHSECONDS))
	if ((left <= 0)); then
		print -r -- "awake: expiring (pid ${_mrgsh_awake_pid})"
		return 0
	fi
	print -r -- "awake: $(_mrgsh_awake_human "$left") remaining (pid ${_mrgsh_awake_pid}, until $(strftime '%H:%M' "$_mrgsh_awake_deadline"))"
}

_mrgsh_awake_stop() {
	if ! _mrgsh_awake_load; then
		print -r -- "awake: not active"
		return 1
	fi
	kill "$_mrgsh_awake_pid" 2>/dev/null
	rm -f -- "$(_mrgsh_awake_statefile)"
	print -r -- "released"
}

awake() {
	case "${1:-}" in
	off | stop | release)
		_mrgsh_awake_stop
		return $?
		;;
	status | st)
		_mrgsh_awake_status
		return $?
		;;
	-h | --help | help)
		_mrgsh_awake_usage
		return 0
		;;
	esac

	local spec="${1:-8h}" secs
	secs="$(_mrgsh_awake_secs "$spec")" || return 1
	_mrgsh_awake_start "$secs" "$spec"
}

_awake() {
	local -a subs=(
		'off:release the assertion'
		'status:time remaining'
		'2h:two hours'
		'4h:four hours'
		'8h:eight hours (default)'
		'30m:thirty minutes'
	)
	((CURRENT == 2)) && _describe 'duration or action' subs
}
((${+functions[compdef]})) && compdef _awake awake
