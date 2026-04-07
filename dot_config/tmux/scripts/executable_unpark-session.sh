#!/usr/bin/env bash
set -euo pipefail

parked=$(tmux list-sessions -f '#{==:#{@parked},1}' -F '#{session_name}|#{session_windows}' 2>/dev/null)

if [[ -z "$parked" ]]; then
  tmux display-message "Unpark: no parked sessions"
  exit 0
fi

cmd=(display-menu -T '#[align=centre] Unpark Session ' -x C -y C -b rounded)
idx=1
while IFS='|' read -r name wins; do
  cmd+=("$name ($wins win)" "$idx" "set -t '$name' -u @parked ; switch-client -t '$name' ; display-message 'Unparked: $name'")
  ((idx++))
done <<< "$parked"

tmux "${cmd[@]}"
