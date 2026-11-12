# shellcheck shell=bash
WS="$SB/ws"
G=(git -c user.name=t -c user.email=t@t.invalid -c commit.gpgsign=false)
mkrepo() { git init -q -b main "$1" && "${G[@]}" -C "$1" commit -q --allow-empty -m init; }
mkdir -p "$WS/a" "$WS/b" "$WS/plain" "$WS/c"
mkrepo "$WS/a/proj"
git clone -q "$WS/a/proj" "$WS/b/proj"
git -C "$WS/a/proj" worktree add -q "$WS/a/proj.fix-x" -b fix-x
git -C "$WS/a/proj" worktree add -q "$WS/a/proj.feat-y" -b feat/y
git -C "$WS/a/proj" worktree add -q --detach "$WS/a/proj-detached"
git -C "$WS/a/proj" worktree add -q "$WS/a/gone" -b gone
rm -rf "$WS/a/gone"
git -C "$WS/a/proj" branch orphan
mkrepo "$WS/c/hooky"
mkdir -p "$WS/c/hooky/.config"
printf 'pre-start = "echo hook-ran >> %s/t/hook.log"\n' "$SB" >"$WS/c/hooky/.config/wt.toml"
git -C "$WS/c/hooky" add .config/wt.toml
"${G[@]}" -C "$WS/c/hooky" commit -q -m hooks
real() { (cd "$1" && pwd -P); }

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

pick() { strict "$SB/cfg/bin/rex-pick-workspace" "$@" 2>&1 || true; }
rows=$(pick --list "" "$WS/a/proj.fix-x" "$S")
check "the picker labels a detached worktree by its directory" \
	grep -q $'^worktree\tproj-detached\t' <<<"$rows"
lacks() { grep -q $'^worktree\tmain\t' <<<"$rows" && ! grep -qF -- "$1" <<<"$rows"; }
check "the picker leaves out a deleted worktree" lacks $'\tgone\t'
check "the picker lists the worktrees first" test "$(head -1 <<<"$rows" | cut -f1)" = worktree
check "the picker leaves out the current session" lacks "$S"
check "the picker lists a worktree that has a session once" lacks "$(sid "$o1")"

pick_usage() {
	local out rc=0
	out=$(strict "$SB/cfg/bin/rex-pick-workspace" "$@" 2>&1 </dev/null) || rc=$?
	[[ "$rc" == 64 && "$out" == "usage: rex-pick-workspace [--list] CLIENT CWD [SESSION [OUT]]" ]]
}
check "the picker with too few arguments prints its usage and exits 64" pick_usage --list ""
check "the picker with too many arguments prints its usage and exits 64" pick_usage a b c d e
pick_fails() {
	local out rc=0
	out=$(strict "$SB/cfg/bin/rex-pick-workspace" --list "" "$WS/plain" session:bogus \
		"$SB/t/pick.out" 2>/dev/null </dev/null) || rc=$?
	[[ "$rc" != 0 && "$out" == "Failed (exit $rc)."$'\n'"Press a key to close." ]] &&
		[[ ! -e "$SB/t/pick.out" && ! -e "$SB/t/pick.out.tmp" ]]
}
touch "$SB/t/pick.out" "$SB/t/pick.out.tmp"
check "a failed picker shows its exit code and removes its hand-off files" pick_fails
pick_plain() {
	local out
	out=$(strict "$SB/cfg/bin/rex-pick-workspace" --list "" "$WS/plain" "$S" 2>&1 </dev/null) &&
		[[ "$out" == *$'session\t'* && "$out" != *worktree* ]]
}
check "the picker outside git lists no worktree" pick_plain

W=$(R new --json wsx -- sh -c 'exec sleep 300' | jq -r .session_id)
pane_in() {
	R window new -s "$W" t -c "$1" --json -- sh -c 'exec sleep 300' | jq -r '.block_ids[0]'
}
key() {
	local q
	q=$(jq -cn --arg s "$W" --arg b "$1" --arg a "$2" --arg o "${3:-key}" \
		'{action: $a, session_id: $s, block_id: $b, origin: $o}')
	R api call -s "$W" client.action "$q" 2>&1 || true
}
pop=
popup_in() {
	local p
	p=$(pane_in "$1")
	sleep 0.3
	opened_json=$(key "$p" popup_workspace)
	pop=$(jq -r '.result.block_id // empty' <<<"$opened_json" 2>/dev/null || true)
}
screen() { R capture -s "$W" -b "$pop" 2>/dev/null; }
see() {
	for _ in $(seq 100); do
		grep -qF -- "$1" <<<"$(screen)" && return 0
		sleep 0.1
	done
	return 1
}
screen_has() { grep -qE -- "$1" <<<"$(screen)"; }
type_pop() {
	R send -s "$W" -b "$pop" "$1" >/dev/null 2>&1 || true
	sleep 0.6
}
selected() { jq -r '.client_actions[]? | select(.action == "session.select") | .args.session_id'; }
pop_gone() { ! grep -qF "$pop" <<<"$(blocks "$W")"; }
close_pop() { R block close -s "$W" "$pop" >/dev/null 2>&1 || true; }

popup_in "$WS/a/proj"
entered() { jq -e '.client_actions[] | select(.action == "client.mode.enter")
	| .args.name == "workspace"' <<<"$opened_json" >/dev/null; }
check "a key press on Alt+W enters the workspace key mode" entered
see 'workspace ❯' || true
aligned() { grep -qE 'worktree [^ ]' <<<"$1" && grep -qE 'session  [^ ]' <<<"$1"; }
check "the picker aligns the kind column" aligned "$(screen)"
type_pop feat
acc=$(key "$pop" workspace_accept)
FY=$(real "$WS/a/proj.feat-y")
same() { [[ -n "$1" && "$1" == "$2" ]]; }
check "Enter in the picker switches the app to the worktree's session" \
	same "$(selected <<<"$acc")" "$(known "$FY")"
left_mode() { jq -e '[.client_actions[].action] | index("client.mode.exit")' >/dev/null; }
check "the switch leaves the workspace key mode" left_mode <<<"$acc"
check "the picker closes after a switch" until5 pop_gone
check "the new workspace starts its agent in the worktree" file_has "$SB/t/agent.cwds" "$FY"

popup_in "$WS/a/proj"
see 'workspace ❯' || true
type_pop orktre
check "the picker searches only the label column" until5 screen_has ' 0/[1-9]'
close_pop

popup_in "$WS/a/proj"
see 'workspace ❯' || true
type_pop fix
type_pop $'\x0f'
see 'Press Enter to open' || true
acc=$(key "$pop" workspace_accept)
FIX=$(git -C "$WS/a/proj" worktree list --porcelain | sed -n 's/^worktree \(.*proj\.fix\)$/\1/p')
check "Ctrl+O creates the typed branch even when it matches a row" \
	git -C "$WS/a/proj" show-ref --verify --quiet refs/heads/fix
check "Enter then switches to the new worktree's session" \
	same "$(selected <<<"$acc")" "$([[ -z "$FIX" ]] || known "$FIX")"
check "the picker closes after a create and Enter" until5 pop_gone
close_pop

stayed() { left_mode <<<"$1" && [[ -z "$(selected <<<"$1")" ]]; }
popup_in "$WS/a/proj"
see 'workspace ❯' || true
type_pop esctest
type_pop $'\x0f'
see 'Press Enter to open' || true
esc=$(key "$pop" workspace_cancel)
check "Esc at the open prompt stays in this session" stayed "$esc"
check "Esc at the open prompt closes the picker" until5 pop_gone
close_pop

popup_in "$WS/a/proj"
see 'workspace ❯' || true
printf '%s\n' "$S" >"$SB/state-home/rex/pick-${W#session:}"
esc=$(key "$pop" workspace_cancel)
check "Esc never takes a pending hand-off" stayed "$esc"
close_pop

popup_in "$WS/a/proj"
see 'workspace ❯' || true
type_pop orphan
type_pop $'\x0f'
check "Ctrl+O on an existing branch opens it in a worktree" see 'Press Enter to open'
close_pop

popup_in "$WS/a/proj"
see 'workspace ❯' || true
type_pop 'bad name'
type_pop $'\x0f'
check "a failed create stays on screen" see 'Press a key to close'
sleep 1
check "a failed create keeps the picker open" grep -q 'Press a key to close' <<<"$(screen)"
close_pop

popup_in "$WS/c/hooky"
see 'workspace ❯' || true
type_pop feature
type_pop $'\x0f'
check "a project hook asks for approval in the picker" see 'needs approval'
type_pop n
key "$pop" workspace_accept >/dev/null
declined() {
	git -C "$WS/c/hooky" show-ref --verify --quiet refs/heads/feature &&
		[[ ! -e "$SB/t/hook.log" ]]
}
check "a declined hook still creates the worktree and runs nothing" until5 declined
close_pop

popup_in "$WS/plain"
see 'workspace ❯' || true
no_create() { grep -q 'workspace ❯' <<<"$1" && ! grep -qiE 'ctrl\+o|create' <<<"$1"; }
check "outside git the header offers no worktree" no_create "$(screen)"
type_pop newthing
key "$pop" workspace_accept >/dev/null
check "outside git a typed name says why nothing happens" see 'Not in a git repository'
close_pop

popup_in "$WS/a/proj"
see 'workspace ❯' || true
esc=$(key "$pop" workspace_cancel)
check "Esc closes the picker" until5 pop_gone
check "Esc leaves the workspace key mode" left_mode <<<"$esc"

stray=$(pane_in "$WS/plain")
stale=$(key "$stray" workspace_accept)
want='[["client.mode.exit",""],["pane.send_key","enter"]]'
passed_on() {
	[[ "$(jq -c '[.client_actions[] | [.action, .args.key // ""]]' <<<"$stale")" == "$want" ]]
}
check "Enter with no picker leaves the mode and passes the key on" passed_on
pal=$(key "$stray" workspace_accept palette)
refused() { grep -q 'focus the workspace picker' <<<"$pal" && ! grep -q send_key <<<"$pal"; }
check "the palette accept presses no key outside the picker" refused

popup_in "$WS/a/proj"
see 'workspace ❯' || true
type_pop t2
type_pop $'\r'
see 'Press Enter to open' || true
type_pop $'\r'
check "an Enter that misses the key mode falls back to the hint" see 'Press Ctrl+Space O and'
close_pop

pop=$(R "do" -s "$W" -b "$stray" --json popup_workspace 2>/dev/null | jq -r '.block_id // empty' ||
	true)
see 'workspace ❯' || true
type_pop t2
type_pop $'\r'
check "without the key mode a failed switch says what to do" see 'Press Ctrl+Space O and'
sleep 3
check "without the key mode the message stays until a key" not pop_gone
close_pop

bare_picker() {
	R window new -s "$W" t -c "$WS/plain" --json -- env -u FZF_DEFAULT_OPTS \
		"$SB/cfg/bin/rex-pick-workspace" "" "$WS/plain" "$W" "" | jq -r '.block_ids[0]'
}
pop=$(bare_picker || true)
see 'workspace ❯' || true
vt() { R capture -s "$W" -b "$pop" --format vt 2>/dev/null; }
check "the picker sets its own fzf colours" grep -q '38;2;243;139;168' <<<"$(vt)"
close_pop
