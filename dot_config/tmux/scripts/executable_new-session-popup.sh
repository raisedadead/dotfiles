#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034

. "$(dirname "$0")/colors.sh"

D="$CLR_DIM"
R="$CLR_RST"
W="$CLR_ACCENT"

printf '\n   %s❯%s ' "$D" "$R"

name=""
while true; do
  IFS= read -r -s -n1 ch
  case "$ch" in
    $'\x1b') exit 0 ;;
    $'\x7f'|$'\b')
      if [ -n "$name" ]; then
        name="${name%?}"
        printf '\b \b'
      fi ;;
    "")
      [ -n "$name" ] && tmux new-session -d -s "$name" && tmux switch-client -t "$name"
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
