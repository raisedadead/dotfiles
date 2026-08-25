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

rows=$(
	index=0
	for one in "${urls[@]}"; do
		index=$((index + 1))
		printf '%d\t%s\n' "$index" "$one"
	done
)

choice=$(
	printf '%s\n' "$rows" |
		fzf --height=100% \
			--no-keep-right \
			--border=rounded \
			--border-label=' URLs ' \
			--prompt='open > ' \
			--delimiter='\t' \
			--no-sort
) || exit 0

url="${choice#*$'\t'}"

if [[ "$url" =~ ^https?:// ]]; then
	open "$url"
else
	printf 'url-picker: refusing non-http target %s\n' "$url" >&2
	exit 1
fi
