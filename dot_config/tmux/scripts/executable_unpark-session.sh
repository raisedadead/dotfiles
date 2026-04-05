#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091,SC2034

. "$(dirname "$0")/colors.sh"

# List parked sessions
parked=$(tmux list-sessions -f '#{==:#{@parked},1}' -F '#{session_name}|#{session_windows}' 2>/dev/null)

if [[ -z "$parked" ]]; then
  tmux display-message "Unpark: no parked sessions"
  exit 0
fi

pick_session() {
  local count
  count=$(wc -l <<< "$parked" | tr -d ' ')

  if [[ "$count" -eq 1 ]]; then
    cut -d'|' -f1 <<< "$parked"
    return
  fi

  while IFS='|' read -r name wins; do
    printf '%s\t%s win\n' "$name" "$wins"
  done <<< "$parked" | fzf \
    --border rounded --border-label=" Unpark Session " \
    --padding=1,2 \
    --color="$FZF_MOCHA_COLORS" \
    --no-info --reverse \
    --delimiter='\t' --with-nth=1,2 \
    --preview-window=hidden | cut -f1
}

selected=$(pick_session)
[[ -z "$selected" ]] && exit 0

if ! tmux has-session -t "$selected" 2>/dev/null; then
  tmux display-message "Unpark: session '$selected' no longer exists"
  exit 1
fi

tmux set -t "$selected" -u @parked
tmux switch-client -t "$selected"
tmux display-message "Unparked: $selected"
