#!/usr/bin/env bash
set -euo pipefail

tmux list-windows -F '#{window_index}:#{@auto-named}' | while IFS=: read -r idx flag; do
  [ "$flag" = "1" ] && tmux rename-window -t ":$idx" "$idx"
done
