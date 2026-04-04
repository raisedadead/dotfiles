#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2154

. "$(dirname "$0")/colors.sh"
. "$(dirname "$0")/input-lib.sh"

printf '\n   %s❯%s ' "$CLR_DIM" "$CLR_RST"

read_inline name || exit 0
tmux new-session -d -s "$name" && tmux switch-client -t "$name"
