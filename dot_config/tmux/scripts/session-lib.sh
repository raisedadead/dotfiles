#!/usr/bin/env bash
# Shared session serialization library for park/save/unpark scripts
# Source this file: . "$(dirname "$0")/session-lib.sh"

PARK_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/parked"

serialize_session() {
  local session="$1" outfile="$2"
  mkdir -p "$(dirname "$outfile")"
  {
    printf 'SESSION=%s\n' "$session"

    tmux list-windows -t "$session" -F '#{window_index}|#{window_name}|#{window_layout}|#{window_active}' | while IFS='|' read -r wi wname wlayout wactive; do
      printf 'WINDOW=%s|%s|%s|%s\n' "$wi" "$wname" "$wlayout" "$wactive"

      tmux list-panes -t "${session}:${wi}" -F '#{pane_index}|#{pane_current_path}|#{pane_current_command}|#{pane_active}' | while IFS='|' read -r pi ppath pcmd pactive; do
        printf 'PANE=%s|%s|%s|%s|%s\n' "$wi" "$pi" "$ppath" "$pcmd" "$pactive"
      done
    done
  } > "$outfile"
}
