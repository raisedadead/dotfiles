#!/usr/bin/env bash
set -euo pipefail

pane="${HERDR_ACTIVE_PANE_ID:-}"
herdr="${HERDR_BIN_PATH:-herdr}"

if [[ -z "$pane" ]]; then
	printf 'url-picker: no active pane\n' >&2
	exit 1
fi

scratch=$(mktemp)
trap 'rm -f "$scratch"' EXIT

"$herdr" pane read "$pane" --source recent-unwrapped --lines 2000 >"$scratch" 2>/dev/null || true

urls=()
while IFS= read -r found; do
	urls+=("$found")
done < <(
	grep -oE 'https?://[][:alnum:]_@:/.,~#%&?+=-]*[[:alnum:]/]' "$scratch" |
		awk '!seen[$0]++' || true
)

if ((${#urls[@]} == 0)); then
	printf 'url-picker: no URLs in pane %s\n' "$pane" >&2
	exit 0
fi

url=$(
	printf '%s\n' "${urls[@]}" |
		fzf --height=100% \
			--no-keep-right \
			--border=rounded \
			--border-label=' URLs ' \
			--prompt='open > ' \
			--no-sort
) || exit 0

if [[ "$url" =~ ^https?:// ]]; then
	open "$url"
else
	printf 'url-picker: refusing non-http target %s\n' "$url" >&2
	exit 1
fi
