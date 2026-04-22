#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2154

. "$(dirname "$0")/colors.sh"
. "$(dirname "$0")/input-lib.sh"

pane_id="$(tmux display-message -p '#{pane_id}')"
pane_path="$(tmux display-message -p '#{pane_current_path}')"

printf '\n   %sBreak to session:%s ' "$CLR_DIM" "$CLR_RST"

read_inline name || exit 0

# shellcheck disable=SC1091
exec "$(dirname "$0")/break-pane-to-session.sh" "$pane_id" "$pane_path" "$name"
