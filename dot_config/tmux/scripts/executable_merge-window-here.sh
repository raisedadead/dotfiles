#!/usr/bin/env bash
set -euo pipefail

# Pick a window via choose-tree (-w = window mode), move it into the
# current session. Inverse of break-pane-to-session (menu: "Break to
# Session"). %% is replaced by tmux with the chosen window target
# (session:window). If the picked window is already in the current
# session, move-window renumbers it within the session — no-op-ish.
exec tmux choose-tree -Zw "move-window -s '%%' -t '#{session_id}:'"
