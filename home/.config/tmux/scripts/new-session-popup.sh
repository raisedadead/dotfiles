#!/usr/bin/env bash

printf '  \033[95mNew session:\033[0m '

name=""
while true; do
  IFS= read -r -s -n1 ch
  case "$ch" in
    $'\x1b') exit 0 ;;          # Escape
    $'\x7f'|$'\b')              # Backspace
      if [ -n "$name" ]; then
        name="${name%?}"
        printf '\b \b'
      fi ;;
    "")                         # Enter
      if [[ "$name" =~ [#\{\}] ]]; then
        printf '\nInvalid characters in session name.\n'
        sleep 1
        exit 1
      fi
      [ -n "$name" ] && tmux new-session -d -s "$name" && tmux switch-client -t "$name"
      exit 0 ;;
    *)
      name="${name}${ch}"
      printf '%s' "$ch" ;;
  esac
done
