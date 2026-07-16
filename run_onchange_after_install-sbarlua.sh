#!/usr/bin/env bash
set -euo pipefail

[[ "$(uname)" == "Darwin" ]] || exit 0

# Pin bump re-triggers install: https://www.chezmoi.io/reference/target-types/scripts/#run_onchange_-scripts
PIN="dba9cc421b868c918d5c23c408544a28aadf2f2f"
DEST="$HOME/.local/share/sketchybar_lua"

[[ -f "$DEST/sketchybar.so" && -f "$DEST/.pin" && "$(cat "$DEST/.pin")" == "$PIN" ]] && exit 0

command -v git >/dev/null || {
	echo "sbarlua: git missing" >&2
	exit 1
}
command -v make >/dev/null || {
	echo "sbarlua: make missing" >&2
	exit 1
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

git clone --quiet https://github.com/FelixKratz/SbarLua.git "$tmp/SbarLua"
git -C "$tmp/SbarLua" checkout --quiet "$PIN"
make -C "$tmp/SbarLua" install
printf '%s\n' "$PIN" >"$DEST/.pin"
echo "sbarlua: installed $PIN"
