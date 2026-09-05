#!/usr/bin/env bash
set -euo pipefail

[[ "$(uname)" == "Darwin" ]] || exit 0

# Pin bump re-triggers install: https://www.chezmoi.io/reference/target-types/scripts/#run_onchange_-scripts
PIN="dba9cc421b868c918d5c23c408544a28aadf2f2f"
DEST="$HOME/.local/share/sketchybar_lua"

[[ -f "$DEST/sketchybar.so" && -f "$DEST/.pin" && "$(cat "$DEST/.pin")" == "$PIN" ]] && exit 0

command -v git >/dev/null || {
	echo "sbarlua: git missing, skipping" >&2
	exit 0
}
command -v make >/dev/null || {
	echo "sbarlua: make missing, skipping" >&2
	exit 0
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# A build failure must not abort the apply. sketchybar Lua is optional; the
# commit guard and every other target are not.
if ! (git clone --quiet https://github.com/FelixKratz/SbarLua.git "$tmp/SbarLua" &&
	git -C "$tmp/SbarLua" checkout --quiet "$PIN" &&
	make -C "$tmp/SbarLua" install); then
	echo "sbarlua: build failed, skipping" >&2
	exit 0
fi
printf '%s\n' "$PIN" >"$DEST/.pin"
echo "sbarlua: installed $PIN"
