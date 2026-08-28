#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2154
set -euo pipefail

. "$(dirname "$0")/colors.sh"
. "$(dirname "$0")/input-lib.sh"

mode="${1-}"

# A popup is not a pane, so #{pane_id} resolves against the client's current pane.
IFS='|' read -r pane_id pane_path < <(tmux display-message -p '#{pane_id}|#{pane_current_path}')

case "$mode" in
  new-window|new-session) printf '\n   %s❯%s ' "$CLR_DIM" "$CLR_RST" ;;
  rename-window)  printf '\n   %s%s%s → ' "$CLR_DIM" "$(tmux display-message -p '#W')" "$CLR_RST" ;;
  rename-session) printf '\n   %s%s%s → ' "$CLR_DIM" "$(tmux display-message -p '#S')" "$CLR_RST" ;;
  break-session)  printf '\n   %sBreak to session:%s ' "$CLR_DIM" "$CLR_RST" ;;
  *) printf 'prompt.sh: unknown mode %s\n' "$mode" >&2; exit 2 ;;
esac

read_inline name || exit 0

case "$mode" in
  new-window)     tmux new-window -n "$name" -c "$pane_path" ;;
  new-session)    tmux new-session -d -s "$name" && tmux switch-client -t "=$name" ;;
  rename-window)  tmux rename-window -- "$name" ;;
  rename-session) tmux rename-session -- "$name" ;;
  break-session)
    if tmux has-session -t "=$name" 2>/dev/null; then
      tmux move-pane -s "$pane_id" -t "$name:"
    else
      tmux new-session -d -s "$name" -c "$pane_path"
      placeholder=$(tmux list-panes -t "=$name" -F '#{pane_id}' | head -1)
      tmux move-pane -s "$pane_id" -t "$name:"
      tmux kill-pane -t "$placeholder"
    fi
    tmux switch-client -t "=$name" ;;
esac
