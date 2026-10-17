#!/usr/bin/env bash
set -euo pipefail

# Cycle to next/previous non-parked session (wraps around), in status-right order
# Usage: cycle-session.sh -n | -p <session_id>

direction="${1:--n}"
current="${2:-}"
[[ -n "$current" ]] || exit 0

read -ra sessions < <(tmux display-message -p '#{S:#{?#{==:#{@parked},1},,#{session_id} }}') || exit 0
count=${#sessions[@]}

[[ "$count" -le 1 ]] && exit 0

idx=0
for i in "${!sessions[@]}"; do
	[[ "${sessions[$i]}" == "$current" ]] && {
		idx=$i
		break
	}
done

if [[ "$direction" == "-n" ]]; then
	next=$(((idx + 1) % count))
else
	next=$(((idx - 1 + count) % count))
fi

tmux switch-client -t "${sessions[$next]}"
