#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091,SC2034

. "$(dirname "$0")/session-lib.sh"

session="${1:-}"

if [[ -z "$session" ]]; then
  session="$(tmux display-message -p '#{session_name}')"
fi

if ! tmux has-session -t "$session" 2>/dev/null; then
  tmux display-message "Save: session '$session' not found"
  exit 1
fi

mkdir -p "$PARK_DIR"
serialize_session "$session" "$PARK_DIR/${session}.park"

tmux display-message "Saved: $session"
