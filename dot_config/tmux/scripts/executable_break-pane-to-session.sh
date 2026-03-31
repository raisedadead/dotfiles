#!/usr/bin/env bash
set -euo pipefail

pane_id="$1"
pane_path="$2"
name="$3"

tmux new-session -d -s "$name" -c "$pane_path"
empty_pane=$(tmux list-panes -t "$name" -F '#{pane_id}' | head -1)
tmux move-pane -s "$pane_id" -t "$name":
tmux kill-pane -t "$empty_pane"
tmux switch-client -t "$name"
