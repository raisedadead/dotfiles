#!/usr/bin/env bash
set -euo pipefail

pane="${HERDR_ACTIVE_PANE_ID:-}"
cwd="${HERDR_ACTIVE_PANE_CWD:-$PWD}"
herdr="${HERDR_BIN_PATH:-herdr}"

if [[ -z "$pane" ]]; then
	printf 'follow: no active pane\n' >&2
	exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
	printf 'follow: jq is required\n' >&2
	exit 1
fi

read -r -e -p "follow command > " cmd || true
if [[ -z "${cmd:-}" ]]; then
	exit 0
fi

width=$(
	"$herdr" pane layout --pane "$pane" 2>/dev/null |
		jq -r --arg p "$pane" '[.result.layout.panes[] | select(.pane_id==$p) | .rect.width] | first // 0' 2>/dev/null
) || width=0

direction=down
if [[ "${width:-0}" =~ ^[0-9]+$ ]] && ((width >= 160)); then
	direction=right
fi

new=$(
	"$herdr" pane split --pane "$pane" --direction "$direction" --cwd "$cwd" --no-focus 2>/dev/null |
		jq -r '.result.pane.pane_id' 2>/dev/null
) || new=""

if [[ -z "${new:-}" || "$new" == "null" ]]; then
	printf 'follow: split failed\n' >&2
	exit 1
fi

"$herdr" pane run "$new" "$cmd" >/dev/null 2>&1

"$herdr" pane send-text "$pane" \
	"Follow pane ${new}. Read it with: herdr pane read ${new} --source recent-unwrapped --lines 200. Block on a marker with: herdr pane wait-output ${new} --regex '<pattern>' --timeout 120000." \
	>/dev/null 2>&1
