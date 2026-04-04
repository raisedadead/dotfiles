#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2154
set -euo pipefail

. "$(dirname "$0")/colors.sh"
. "$(dirname "$0")/input-lib.sh"

target="${1:-window}"

if [[ "$target" == "session" ]]; then
  current="$(tmux display-message -p '#S')"
else
  current="$(tmux display-message -p '#W')"
fi

printf '\n   %s%s%s → ' "$CLR_DIM" "$current" "$CLR_RST"

read_inline name || exit 0
if [[ "$target" == "session" ]]; then
  tmux rename-session "$name"
else
  tmux rename-window "$name"
  tmux set -w @auto-named 0
fi
