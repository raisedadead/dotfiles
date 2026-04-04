#!/usr/bin/env bash
# Shared inline character input for tmux popup prompts
# Source this file: . "$(dirname "$0")/input-lib.sh"
# Requires colors.sh to be sourced first (uses CLR_ACCENT, CLR_RST)

# shellcheck disable=SC2034
read_inline() {
  local -n _result="$1"
  _result=""
  while true; do
    IFS= read -r -s -n1 ch
    case "$ch" in
      $'\x1b') return 1 ;;
      $'\x7f'|$'\b')
        if [[ -n "$_result" ]]; then
          _result="${_result%?}"
          printf '\b \b'
        fi ;;
      "")
        [[ -n "$_result" ]] && return 0
        return 1 ;;
      '#'|'{'|'}')
        printf '%s%s%s' "$CLR_ACCENT" "$ch" "$CLR_RST"
        sleep 0.15
        printf '\b \b' ;;
      *)
        _result="${_result}${ch}"
        printf '%s' "$ch" ;;
    esac
  done
}
