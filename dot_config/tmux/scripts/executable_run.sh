#!/usr/bin/env bash
set -uo pipefail

LOG_MAX_BYTES=262144
LOG_KEEP_BYTES=65536

name="${1:-}"
if [[ -z "$name" ]]; then
	tmux display-message "tmux run: no script named"
	exit 0
fi
shift

dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ "$name" == /* ]]; then
	target="$name"
elif [[ "$name" == */* ]]; then
	tmux display-message "tmux run: rejected script name '$name'"
	exit 0
else
	target="$dir/$name"
fi

if [[ ! -x "$target" ]]; then
	tmux display-message "tmux run: '$name' is missing or not executable"
	exit 0
fi

base=$(basename -- "$name")
log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/tmux"
log="$log_dir/${base%.sh}.log"

if ! mkdir -p "$log_dir" 2>/dev/null || ! : >>"$log" 2>/dev/null; then
	log=/dev/null
fi

if [[ -f "$log" && $(wc -c <"$log" 2>/dev/null || printf 0) -gt $LOG_MAX_BYTES ]]; then
	if trim=$(mktemp "$log.XXXXXX" 2>/dev/null); then
		tail -c $LOG_KEEP_BYTES "$log" >"$trim" 2>/dev/null && mv -f "$trim" "$log" 2>/dev/null
		rm -f "$trim"
	fi
fi

status=0
"$target" "$@" >>"$log" 2>&1 || status=$?

if ((status != 0)); then
	printf '%s %s exit %d\n' "$(date -u +%FT%TZ)" "$base" "$status" >>"$log" 2>/dev/null
	tmux display-message "tmux: $base exit $status - $log"
fi

exit 0
