#!/usr/bin/env bash
set -euo pipefail

# Pick a pane via choose-tree, join it into the current window as a
# horizontal split. Inverse of `break-pane` (menu: "Break to Window").
# %% is replaced by tmux with the chosen pane target (session:window.pane).
exec tmux choose-tree -Z "join-pane -h -s '%%'"
