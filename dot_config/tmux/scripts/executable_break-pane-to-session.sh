#!/usr/bin/env bash
set -euo pipefail

pane_id="$1"
pane_path="$2"
name="$3"

if [[ -z "$name" ]]; then
  tmux display-message "Break to session: empty name"
  exit 1
fi

if tmux has-session -t "=$name" 2>/dev/null; then
  # Session exists: move pane to it as a new window, then switch
  tmux move-pane -s "$pane_id" -t "$name:"
  tmux switch-client -t "=$name"
else
  # Create new session, swap pane in, kill the placeholder pane
  tmux new-session -d -s "$name" -c "$pane_path"
  empty_pane=$(tmux list-panes -t "$name" -F '#{pane_id}' | head -1)
  tmux move-pane -s "$pane_id" -t "$name:"
  tmux kill-pane -t "$empty_pane"
  tmux switch-client -t "=$name"
fi
