#!/usr/bin/env bash
set -euo pipefail

direction="${1:?usage: navigate.sh <left|down|up|right> <key>}"
key="${2:?usage: navigate.sh <left|down|up|right> <key>}"
pane="${HERDR_ACTIVE_PANE_ID:-}"
herdr="${HERDR_BIN_PATH:-herdr}"

[[ -n "$pane" ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

forward() { "$herdr" pane send-keys "$pane" "$key" >/dev/null 2>&1 || true; }

vim_re='^g?(view|l?n?vim?x?)(diff)?$'
extra_re="${HERDR_NAV_PASSTHROUGH_RE:-}"

if "$herdr" pane process-info --pane "$pane" 2>/dev/null |
	jq -e --arg vim "$vim_re" --arg extra "$extra_re" \
		'.result.process_info.foreground_processes[]?.name
     | ascii_downcase
     | select(test($vim) or ($extra != "" and (try test($extra) catch false)))' >/dev/null 2>&1; then
	forward
	exit 0
fi

focus=$("$herdr" pane focus --direction "$direction" --pane "$pane" 2>/dev/null) || focus=""
changed=$(printf '%s' "$focus" | jq -r '.result.focus.changed // false' 2>/dev/null || echo false)

[[ "$changed" == "true" ]] || forward
