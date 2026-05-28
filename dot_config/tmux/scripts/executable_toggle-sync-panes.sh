#!/usr/bin/env bash
# Toggle synchronize-panes for a window and reset pane-active-border-style.
#
# Works around tmux format-expansion timing: in chained `setw foo \; run '... #{foo} ...'`,
# tmux expands all `#{...}` formats at parse time of the whole command list, BEFORE
# dispatching. The conditional in `run` therefore sees PRE-toggle state. This script
# re-reads the option via `tmux show -w -v` post-toggle, which is authoritative.
#
# Args:
#   $1 — window id (e.g. @7)
#   $2 — red (sync-on)  border colour (e.g. #f38ba8)
#   $3 — sapphire (sync-off) border colour (e.g. #74c7ec)

set -euo pipefail

W="${1:?window-id required}"
RED="${2:-#f38ba8}"
SAPPHIRE="${3:-#74c7ec}"

tmux setw -t "$W" synchronize-panes

sync=$(tmux show -w -t "$W" -v synchronize-panes 2>/dev/null || printf 'off')
panes=$(tmux display -p -t "$W" '#{window_panes}')

tmux set -t "$W" pane-border-lines single

if [[ "$sync" == "on" ]]; then
	tmux set -t "$W" pane-active-border-style "fg=$RED"
	tmux set -t "$W" pane-border-status bottom
else
	tmux set -t "$W" pane-active-border-style "fg=$SAPPHIRE"
	if [[ "$panes" -gt 1 ]]; then
		tmux set -t "$W" pane-border-status bottom
	else
		tmux set -t "$W" pane-border-status off
	fi
fi
