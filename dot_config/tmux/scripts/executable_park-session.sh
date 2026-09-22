#!/usr/bin/env bash
set -euo pipefail

session="${1:-$(tmux display-message -p '#{session_name}' 2>/dev/null || true)}"
[[ -n "$session" ]] || exit 0

if ! tmux has-session -t "$session" 2>/dev/null; then
	tmux display-message "Park: session '$session' not found"
	exit 0
fi

if [[ "$(tmux show -t "$session" -v @parked 2>/dev/null)" == "1" ]]; then
	tmux display-message "Park: '$session' is already parked"
	exit 0
fi

# Tag session as parked — processes keep running
tmux set -t "$session" @parked 1

# Count non-parked sessions (excluding the one we just parked)
visible=$(tmux list-sessions -f '#{!=:#{@parked},1}' -F '#{session_name}' | wc -l | tr -d ' ')

if [[ "$visible" -eq 0 ]]; then
	tmux new-session -d -s scratch
fi

current="$(tmux display-message -p '#{client_session}' 2>/dev/null || true)"
if [[ "$current" == "$session" ]]; then
	next=$(tmux list-sessions -f '#{!=:#{@parked},1}' -F '#{session_name}' | head -1)
	tmux switch-client -t "$next"
fi

tmux display-message "Parked: $session (still running)"
