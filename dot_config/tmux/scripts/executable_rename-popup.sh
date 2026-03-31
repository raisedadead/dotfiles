#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034
set -euo pipefail

. "$(dirname "$0")/colors.sh"

D="$CLR_DIM"
R="$CLR_RST"
W="$CLR_ACCENT"

target="${1:-window}"

if [[ "$target" == "session" ]]; then
  current="$(tmux display-message -p '#S')"
else
  current="$(tmux display-message -p '#W')"
fi

printf '\n   %s%s%s → ' "$D" "$current" "$R"

name=""
while true; do
  IFS= read -r -s -n1 ch
  case "$ch" in
    $'\x1b') exit 0 ;;
    $'\x7f'|$'\b')
      if [[ -n "$name" ]]; then
        name="${name%?}"
        printf '\b \b'
      fi ;;
    "")
      if [[ -n "$name" ]]; then
        if [[ "$target" == "session" ]]; then
          tmux rename-session "$name"
        else
          tmux rename-window "$name"
          tmux set -w @auto-named 0
        fi
      fi
      exit 0 ;;
    '#'|'{'|'}')
      printf '%s%s%s' "$W" "$ch" "$R"
      sleep 0.15
      printf '\b \b' ;;
    *)
      name="${name}${ch}"
      printf '%s' "$ch" ;;
  esac
done
