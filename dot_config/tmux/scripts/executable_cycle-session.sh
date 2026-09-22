#!/usr/bin/env bash
set -euo pipefail

# Cycle to next/previous non-parked session (wraps around)
# Usage: cycle-session.sh -n | -p

direction="${1:--n}"
current=$(tmux display-message -p '#{session_id}' 2>/dev/null) || exit 0

mapfile -t sessions < <(tmux list-sessions -f '#{!=:#{@parked},1}' -F '#{session_id}')
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
