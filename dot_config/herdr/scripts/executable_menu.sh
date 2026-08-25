#!/usr/bin/env bash
set -euo pipefail

pane="${HERDR_ACTIVE_PANE_ID:-}"
herdr="${HERDR_BIN_PATH:-herdr}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "$pane" ]]; then
	printf 'menu: no active pane\n' >&2
	exit 1
fi

run() { "$herdr" "$@" >/dev/null 2>&1 || true; }

choice=$(
	fzf --height=100% \
		--no-keep-right \
		--border=rounded \
		--border-label=' Commands ' \
		--prompt='run > ' \
		--no-sort \
		--with-nth=2.. <<'ROWS'
break-tab	Break pane to a new tab
break-workspace	Break pane to a new workspace
swap-left	Swap pane left
swap-right	Swap pane right
swap-up	Swap pane up
swap-down	Swap pane down
zoom	Toggle zoom
urls	Pick a URL from this pane
rename-pane	Rename this pane
close-pane	Close this pane
ROWS
) || exit 0

action="${choice%%	*}"

case "$action" in
break-tab) run pane move "$pane" --new-tab ;;
break-workspace) run pane move "$pane" --new-workspace ;;
swap-left) run pane swap --direction left --pane "$pane" ;;
swap-right) run pane swap --direction right --pane "$pane" ;;
swap-up) run pane swap --direction up --pane "$pane" ;;
swap-down) run pane swap --direction down --pane "$pane" ;;
zoom) run pane zoom "$pane" --toggle ;;
urls) exec "$here/url-picker.sh" ;;
rename-pane)
	read -r -p "pane name: " name || true
	if [[ -n "${name:-}" ]]; then
		run pane rename "$pane" "$name"
	fi
	;;
close-pane) run pane close "$pane" ;;
esac
