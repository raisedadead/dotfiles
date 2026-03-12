#!/usr/bin/env bash

D=$'\033[90m'  # dim
R=$'\033[0m'   # reset
W=$'\033[33m'  # yellow (warning)

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
