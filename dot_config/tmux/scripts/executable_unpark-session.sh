#!/usr/bin/env bash
set -euo pipefail

# Use #{session_id} ($N) — quote-safe; see session-menu.sh for rationale (audit B2).
parked=$(tmux list-sessions -f '#{==:#{@parked},1}' -F '#{session_id}|#{session_name}|#{session_windows}' 2>/dev/null)

if [[ -z "$parked" ]]; then
  tmux display-message "Unpark: no parked sessions"
  exit 0
fi

cmd=(display-menu -T '#[align=centre] Unpark Session ' -x C -y C -b rounded)
idx=1
while IFS='|' read -r sid name wins; do
  cmd+=("$name ($wins win)" "$idx" "set -t $sid -u @parked ; switch-client -t $sid ; display-message 'Unparked'")
  ((idx++))
done <<< "$parked"

tmux "${cmd[@]}"
