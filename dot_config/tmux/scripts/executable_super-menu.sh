#!/usr/bin/env bash
# shellcheck disable=SC1091
# SuperMenu — focused tv-powered launcher (M-m)
# Presents 3 modes, then exec's into the selected tv channel.

. "$(dirname "$0")/colors.sh"

_ico_project=$'\U000F0770'   # nf-md-folder_open
_ico_session=$'\U000F018D'   # nf-md-console
_ico_files=$'\U000F0219'     # nf-md-file_multiple

selected=$(printf '%s  Projects\n%s  Sessions\n%s  Files' \
  "$_ico_project" "$_ico_session" "$_ico_files" \
  | fzf --no-info --no-sort --ansi --cycle \
    --color="$FZF_MOCHA_COLORS" \
    --prompt="SuperMenu ❯ " \
    --border=none --padding=0 \
    --bind 'esc:abort')

[ -z "$selected" ] && exit 0

case "$selected" in
  *Projects*) exec tv projects ;;
  *Sessions*) exec tv sesh ;;
  *Files*)    exec tv files ;;
esac
