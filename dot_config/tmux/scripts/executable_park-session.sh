#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091,SC2034

. "$(dirname "$0")/session-lib.sh"

session="${1:-}"

if [[ -z "$session" ]]; then
  session="$(tmux display-message -p '#{session_name}')"
fi

if ! tmux has-session -t "$session" 2>/dev/null; then
  tmux display-message "Park: session '$session' not found"
  exit 1
fi

mkdir -p "$PARK_DIR"
serialize_session "$session" "$PARK_DIR/${session}.park"

others=$(tmux list-sessions -F '#{session_name}' | grep -cv "^${session}$" || true)
current="$(tmux display-message -p '#{client_session}')"

if [[ "$others" -eq 0 ]]; then
  tmux new-session -d -s scratch
fi

if [[ "$current" == "$session" ]]; then
  next=$(tmux list-sessions -F '#{session_name}' | grep -v "^${session}$" | head -1)
  tmux switch-client -t "$next"
fi

tmux kill-session -t "$session"
tmux display-message "Parked: $session"
