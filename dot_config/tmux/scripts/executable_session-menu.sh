#!/usr/bin/env bash
set -euo pipefail

# Use #{session_id} ($N) as the switch target — guaranteed quote-safe.
# Avoids fragile bash-style escaping of session names that may contain
# apostrophes, quotes, or other tmux-quoting hazards (audit B2).
sessions=$(tmux list-sessions -F '#{session_id}|#{session_name}|#{session_windows}|#{@parked}|#{session_last_attached}' 2>/dev/null)

if [[ -z "$sessions" ]]; then
  tmux display-message "No sessions"
  exit 0
fi

KEYS="123456789abcdefghijklmnopqrstuvwxyz"

cmd=(display-menu -T '#[align=centre] Sessions ' -x C -y C -b rounded \
  -s 'fg=#cdd6f4,bg=#1e1e2e' -S 'fg=#6c7086' -H 'fg=#1e1e2e,bg=#cba6f7,bold')

active_lines=()
parked_lines=()

while IFS='|' read -r sid name wins parked _last; do
  if [[ "$parked" == "1" ]]; then
    parked_lines+=("$sid|$name|$wins")
  else
    active_lines+=("$sid|$name|$wins")
  fi
done < <(sort -t'|' -k5 -rn <<< "$sessions")

idx=0

for entry in "${active_lines[@]}"; do
  IFS='|' read -r sid name wins <<< "$entry"
  cmd+=("$name ($wins win)" "${KEYS:$idx:1}" "switch-client -t $sid")
  idx=$((idx + 1))
done

if [[ ${#parked_lines[@]} -gt 0 ]]; then
  cmd+=("" "" "")
  for entry in "${parked_lines[@]}"; do
    IFS='|' read -r sid name wins <<< "$entry"
    cmd+=("$name ($wins win) [parked]" "${KEYS:$idx:1}" "set -t $sid -u @parked ; switch-client -t $sid ; display-message 'Unparked'")
    idx=$((idx + 1))
  done
fi

tmux "${cmd[@]}"
