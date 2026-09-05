#!/usr/bin/env bash
# Toggle synchronize-panes for a window and reconcile its pane-border-status.
# The condition must match theme.conf's config-load loop and both set-hooks, or a
# sync toggle hides a COPY row that a single-pane window still needs.
#
# Works around tmux format-expansion timing: in chained `setw foo \; run '... #{foo} ...'`,
# tmux expands all `#{...}` formats at parse time of the whole command list, BEFORE
# dispatching. The conditional in `run` therefore sees PRE-toggle state. This script
# re-reads the option via `tmux show -w -v` post-toggle, which is authoritative.
#
# The border COLOUR needs no help: pane-active-border-style is a global format
# that already resolves red on #{?pane_synchronized,...}, and tmux repaints on
# the toggle.
#
# Args:
#   $1 — window id (e.g. @7)

set -euo pipefail

W="${1:?window-id required}"

tmux setw -t "$W" synchronize-panes

sync=$(tmux show -w -t "$W" -v synchronize-panes 2>/dev/null || printf 'off')
panes=$(tmux display -p -t "$W" '#{window_panes}')
mode=$(tmux display -p -t "$W" '#{pane_in_mode}')

tmux set -t "$W" pane-border-lines single

if [[ "$sync" == "on" || "$panes" -gt 1 || "$mode" == 1 ]]; then
	tmux set -t "$W" pane-border-status top
else
	tmux set -t "$W" pane-border-status off
fi
