# shellcheck shell=bash
WS="$SB/ws"
G=(git -c user.name=t -c user.email=t@t.invalid -c commit.gpgsign=false)
mkrepo() { git init -q -b main "$1" && "${G[@]}" -C "$1" commit -q --allow-empty -m init; }
mkdir -p "$WS/a" "$WS/b" "$WS/plain"
mkrepo "$WS/a/proj"
git clone -q "$WS/a/proj" "$WS/b/proj"
git -C "$WS/a/proj" worktree add -q "$WS/a/proj.fix-x" -b fix-x

wso() { R "do" -s "$S" --json workspace_open "path=$1" "name=$2" 2>&1 || true; }
sid() { jq -r '.session_id // empty' <<<"$1" 2>/dev/null || true; }
known() {
	R "do" -s "$S" --json workspace_known 2>/dev/null | jq -r --arg p "$1" '.paths[$p] // empty'
}

o1=$(wso "$WS/a/proj.fix-x" fixer)
R session rename "$(sid "$o1")" login-redirect-fix >/dev/null 2>&1 || true
o2=$(wso "$WS/a/proj.fix-x" fixer)
R config reload >/dev/null 2>&1 || true
o3=$(wso "$WS/a/proj.fix-x" fixer-again)
same_place() {
	local a b c
	a=$(sid "$o1") b=$(sid "$o2") c=$(sid "$o3")
	[[ -n "$a" && "$a" == "$b" && "$b" == "$c" ]]
}
check "workspace_open finds a renamed session by its path, after a reload" same_place

c1=$(wso "$WS/a/proj" proj-main)
c2=$(wso "$WS/b/proj" proj-main)
label_of() { R ls --json | jq -r --arg s "$1" '.sessions[] | select(.session_id == $s) | .label'; }
two_clones() {
	[[ -n "$(sid "$c2")" && "$(sid "$c1")" != "$(sid "$c2")" ]] &&
		[[ "$(label_of "$(sid "$c2")")" != proj-main ]]
}
check "two clones with one basename get two sessions and two labels" two_clones

missing=$(wso "$WS/a/gone" proj-gone)
check "workspace_open refuses a missing directory" grep -q "no such directory" <<<"$missing"
check "a missing directory gets no session" \
	not grep -q '"proj-gone"' <<<"$(R ls --json)"
long=$(printf 'x%.0s' $(seq 140))
long_sid=$(sid "$(wso "$WS/plain" "$long")")
check "workspace_open clamps a long name to the label limit" \
	test -n "$long_sid" -a "$(label_of "$long_sid" | wc -c)" -le 129
