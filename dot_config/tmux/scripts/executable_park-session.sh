#!/usr/bin/env bash
set -euo pipefail

PARK_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/parked"
mkdir -p "$PARK_DIR"

session="${1:-}"

if [[ -z "$session" ]]; then
  session="$(tmux display-message -p '#{session_name}')"
fi

if ! tmux has-session -t "$session" 2>/dev/null; then
  tmux display-message "Park: session '$session' not found"
  exit 1
fi

sessions=$(tmux list-sessions -F '#{session_name}' | wc -l | tr -d ' ')
if [[ "$sessions" -le 1 ]]; then
  tmux display-message "Park: cannot park the only session"
  exit 1
fi

outfile="$PARK_DIR/${session}.park"

{
  printf 'SESSION=%s\n' "$session"

  tmux list-windows -t "$session" -F '#{window_index}|#{window_name}|#{window_layout}|#{window_active}' | while IFS='|' read -r wi wname wlayout wactive; do
    printf 'WINDOW=%s|%s|%s|%s\n' "$wi" "$wname" "$wlayout" "$wactive"

    tmux list-panes -t "${session}:${wi}" -F '#{pane_index}|#{pane_current_path}|#{pane_current_command}|#{pane_active}' | while IFS='|' read -r pi ppath pcmd pactive; do
      printf 'PANE=%s|%s|%s|%s|%s\n' "$wi" "$pi" "$ppath" "$pcmd" "$pactive"
    done
  done
} > "$outfile"

current="$(tmux display-message -p '#{client_session}')"
if [[ "$current" == "$session" ]]; then
  next=$(tmux list-sessions -F '#{session_name}' | grep -v "^${session}$" | head -1)
  tmux switch-client -t "$next"
fi

tmux kill-session -t "$session"
tmux display-message "Parked: $session"
