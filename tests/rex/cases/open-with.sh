# shellcheck shell=bash
OW="$SB/ow"
mkdir -p "$OW/sub"
seq -f 'line %g of main' 20 >"$OW/main.lua"
seq -f 'colon %g' 9 >"$OW/x:3"
printf 'dash file\n' >"$OW/-x.md"
ow_nvim="$(command -v nvim) --clean -n"
ow_open() {
	(cd "$OW" && env REX_SERVER="$SOCK" REX_SESSION="$S" TMUX= TERM_PROGRAM=rex \
		EDITOR="$ow_nvim" "$SB/cfg/bin/rex-open" "$1")
}
ow_id() { blocks "$S" | awk -v l="$1" '$1 == l { print $3 }' | tail -1; }
ow_sees() {
	local id
	id=$(ow_id "$1")
	[[ -n "$id" ]] && grep -qE "$2" <<<"$(R capture -s "$S" -b "$id" 2>/dev/null)"
}
ow_close() {
	local id
	id=$(ow_id "$1")
	[[ -z "$id" ]] || R block close -s "$S" "$id" >/dev/null 2>&1 || true
}

ow_open main.lua:12:5
check "rex-open FILE:LINE:COL opens the file" until5 ow_sees edit:main.lua 'line 1 of main'
check "rex-open FILE:LINE:COL puts the cursor at the column" \
	until5 ow_sees edit:main.lua ' 12,5 '
ow_close edit:main.lua

ow_open new.lua:3:2
check "rex-open FILE:LINE:COL on a new file names the file" until5 has_label "$S" edit:new.lua
ow_close edit:new.lua

ow_open x:3:5
check "rex-open keeps a colon that is part of the name" until5 ow_sees edit:x:3 'colon 1'
check "rex-open goes to the line in a name with a colon" until5 ow_sees edit:x:3 ' 5,1 '
ow_close edit:x:3

ow_open -x.md
check "rex-open opens a file whose name starts with a dash" \
	until5 ow_sees edit:-x.md 'dash file'
ow_close edit:-x.md

ow_open sub/
check "rex-open labels a directory with a trailing slash" until5 has_label "$S" edit:sub
ow_close edit:sub

ow_open main.lua:12:5:
check "rex-open drops a trailing colon after FILE:LINE:COL" \
	until5 ow_sees edit:main.lua ' 12,5 '
ow_close edit:main.lua

ow_open main.lua:010:5
check "rex-open reads a line with a leading zero as decimal" \
	until5 ow_sees edit:main.lua ' 10,5 '
ow_close edit:main.lua
