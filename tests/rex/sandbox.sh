#!/usr/bin/env bash
set -euo pipefail

REPO=$(cd "$(dirname "$0")/../.." && pwd)
SRC="$REPO/dot_config/rex"
SB=$(mktemp -d /tmp/rexsb.test.XXXXXX)
SOCK="unix://$SB/server.sock"
fails=0

R() { rex -S "$SOCK" --autostart=false "$@"; }
ok() { printf 'ok   %s\n' "$1"; }
bad() {
	printf 'FAIL %s\n' "$1"
	fails=$((fails + 1))
}
check() { if "${@:2}"; then ok "$1"; else bad "$1"; fi; }

server_pid=
cleanup() {
	R server stop >/dev/null 2>&1 || true
	[[ -z "$server_pid" ]] || kill "$server_pid" 2>/dev/null || true
	rm -rf "$SB"
}
trap cleanup EXIT

mkdir -p "$SB/cfg" "$SB/state" "$SB/t"
cp "$SRC"/*.lua "$REPO/tests/rex/testkit.lua" "$SB/cfg/"
printf '\nrequire("testkit")\n' >>"$SB/cfg/init.lua"
mkdir -p "$SB/cfg/bin"
for f in "$SRC"/bin/executable_*; do
	install -m 755 "$f" "$SB/cfg/bin/$(basename "${f#*/executable_}")"
done

REX_SERVER="$SOCK" rex server run --listen "$SOCK" --state-dir "$SB/state" \
	--config "$SB/cfg/init.lua" --restore=false >"$SB/server.log" 2>&1 &
server_pid=$!
for _ in $(seq 50); do
	R server status >/dev/null 2>&1 && break
	sleep 0.1
done
R server status >/dev/null || {
	tail -5 "$SB/server.log"
	exit 1
}

blocks() {
	R api call -s "$1" session.list_blocks |
		jq -r '.blocks[] | "\(.label // "-") \(.placement) \(.block_id)"'
}
until5() {
	for _ in $(seq 50); do
		"$@" && return 0
		sleep 0.1
	done
	return 1
}
no_label() { ! grep -q "^$2 " <<<"$(blocks "$1")"; }
has_label() { grep -q "^$2 " <<<"$(blocks "$1")"; }
file_has() { grep -q "$2" "$1" 2>/dev/null; }
clean_check() { rex config check "$1" --json | jq -e '.diagnostics == []' >/dev/null; }
loaded() { grep -q "$1" <<<"$(R actions)"; }
no_fn_keys() { ! grep -q client.key.forward <<<"$(R keymap)"; }
fails_with() {
	local s=$1 pat=$2
	shift 2
	grep -q "$pat" <<<"$(R "do" -s "$s" "$@" 2>&1)"
}
untyped() { ! grep -q typed "$1" 2>/dev/null; }

renders() {
	local tmpl="$REPO/run_onchange_after_rex-defaults.sh.tmpl" out="$SB/defaults.sh"
	chezmoi execute-template <"$tmpl" >"$out" &&
		bash -n "$out" && grep -q "Workspace.customThemes" "$out"
}
check "app settings script renders and parses" renders

S=$(R new --json t1 -- sh -c 'exec sleep 300' | jq -r .session_id)

check "config check on the source" clean_check "$SRC/init.lua"
check "test kit loads beside the config copy" loaded t_write
check "no key binds a Lua function" no_fn_keys

R "do" -s "$S" probe_popup >/dev/null
check "probe popup opens" has_label "$S" probe
check "probe popup closes on exit" until5 no_label "$S" probe
R new --json t2 -- sh -c 'exec sleep 300' >/dev/null
check "probe switch queues to the app" fails_with "$S" "no client is targeted" probe_switch

split() { R split -s "$S" --json -- "$@" | jq -r '.block_ids[0]'; }
plain=$(split sh -c "cat > '$SB/t/plain'")
agent=$(split bash -c "exec -a claude cat > '$SB/t/agent'")
secret=$(split bash -c "read -rs x; echo \"\$x\" > '$SB/t/secret'")
sleep 0.5
write_to() { R "do" -s "$S" t_write "block=$1" $'text=typed\n' 2>&1 || true; }
write_to "$plain" >/dev/null
check "safe_write types into a plain program" until5 file_has "$SB/t/plain" typed
check "safe_write refuses an agent" grep -q "claude runs in" <<<"$(write_to "$agent")"
check "safe_write refuses a password prompt" grep -q "reads a password" <<<"$(write_to "$secret")"
check "safe_write fails closed on an unknown pane" grep -q "refused:" <<<"$(write_to block:bogus)"
sleep 0.3
check "the agent got no input" untyped "$SB/t/agent"
check "the password prompt got no input" untyped "$SB/t/secret"

keymap=$(R keymap)
bound() { grep -qE "^$1 +$2( |$)" <<<"$keymap"; }
check "alt+shift+h runs nav" bound "alt\+shift\+h" nav
check "alt+d splits right" bound "alt\+d" "pane\.split\.right"
check "alt+o opens the session picker" bound "alt\+o" "session\.switch"
check "alt+1 goes to tab 1" bound "alt\+1" "client\.tab\.goto"
check "ctrl+space x closes the pane" bound "ctrl\+space x" close_pane
check "ctrl+space shift+r enters resize" bound "ctrl\+space shift\+r" "client\.mode\.enter"
check "resize mode h resizes left" bound "resize/h" "pane\.resize"

nvim=$(split bash -c "stty raw -echo; exec -a nvim dd bs=1 count=2 of='$SB/t/nvim'")
sleep 0.3
R "do" -s "$S" nav "block=$nvim" dir=left >/dev/null 2>&1 || true
check "nav types Alt+Shift+H into Neovim" until5 file_has "$SB/t/nvim" $'\x1bH'
check "nav moves focus outside Neovim" \
	fails_with "$S" "no client is targeted" nav "block=$plain" dir=left

doomed=$(split sh -c 'exec sleep 300')
R "do" -s "$S" close_pane "block=$doomed" >/dev/null 2>&1 || true
gone() { ! grep -q "$1" <<<"$(blocks "$S")"; }
check "close_pane closes the block" until5 gone "$doomed"

bin_is_local() { [[ "$(R "do" -s "$S" --json t_bin | jq -r .bin)" == "$SB/cfg/bin/" ]]; }
check "helpers run from the config's own bin" bin_is_local

opened() {
	R "do" -s "$S" "$1" >/dev/null 2>&1 || return 1
	local id
	id=$(blocks "$S" | awk -v l="$2" '$1 == l { print $3 }')
	[[ -n "$id" ]] && R block close -s "$S" "$id" >/dev/null 2>&1
}
for p in lazygit reader keys urls; do
	check "popup_$p opens popup:$p" opened "popup_$p" "popup:$p"
done

text='see https://example.com/a, (http://x.test/b) and https://example.com/a'
linky=$(split sh -c "echo '$text'; exec sleep 300")
sleep 0.5
links() { REX_SERVER="$SOCK" "$SB/cfg/bin/rex-urls" --list "$S" "$linky" | sort | tr '\n' ' '; }
check "rex-urls lists each link once" test "$(links)" = "http://x.test/b https://example.com/a "

drawer() { R "do" -s "$S" --json drawer_scratch | jq -r .state; }
d1=$(drawer)
did=$(blocks "$S" | awk '$1 == "drawer:scratch" { print $3 }')
d2=$(drawer)
placement() { blocks "$S" | awk -v i="$did" '$3 == i { print $2 }'; }
p2=$(placement)
d3=$(drawer)
steps="$d1 $d2 $p2 $d3 $(placement)"
check "drawer opens, hides, shows" test "$steps" = "created hidden detached shown placed"

rex_rows() {
	env REX_SERVER="$SOCK" TERM_PROGRAM=rex REX_SESSION="$S" TMUX= \
		python3 "$REPO/exact_dot_bin/executable_keys" --plain 2>/dev/null | grep -c '^rex '
}
check "keys lists the Rex bindings inside Rex" test "$(rex_rows)" -gt 40

printf '#!/bin/sh\necho "$@" > %s/t/editor.args\nsleep 5\n' "$SB" >"$SB/editor"
chmod +x "$SB/editor"
open_in() {
	env REX_SERVER="$SOCK" REX_SESSION="$S" TMUX= TERM_PROGRAM="$1" EDITOR="$SB/editor" \
		"$SB/cfg/bin/rex-open" "$SB/t/notes.md:12"
}
open_in rex
check "rex-open starts the editor at the line" \
	until5 file_has "$SB/t/editor.args" "+12 $SB/t/notes.md"
check "rex-open opens a tab labelled edit:notes.md" has_label "$S" edit:notes.md
rm -f "$SB/t/editor.args"
before=$(blocks "$S" | wc -l)
open_in ghostty
check "rex-open outside Rex runs the editor in place" file_has "$SB/t/editor.args" "+12"
check "rex-open outside Rex opens no tab" test "$(blocks "$S" | wc -l)" -le "$before"

printf '#!/bin/sh\npwd > %s/t/agent.cwd\n' "$SB" >"$SB/fake-agent"
chmod +x "$SB/fake-agent"
mkdir -p "$SB/proj"
R "do" -s "$S" layout_agent "cwd=$SB/proj" "agent=$SB/fake-agent" >/dev/null
check "layout_agent starts the agent in the cwd" until5 file_has "$SB/t/agent.cwd" "$SB/proj"
check "layout_agent labels the agent pane" has_label "$S" agent
ws() { R "do" -s "$S" --json workspace_open "path=$SB/proj" name=ws1 "agent=$SB/fake-agent"; }
w1=$(ws)
w2=$(ws)
same_ws() {
	[[ "$(jq -r .created <<<"$w1") $(jq -r .created <<<"$w2")" == "true false" ]] &&
		[[ "$(jq -r .session_id <<<"$w1")" == "$(jq -r .session_id <<<"$w2")" ]]
}
check "workspace_open creates once, then finds the session" same_ws
git -C "$SB/proj" init -q
pick_rows() { REX_SERVER="$SOCK" "$SB/cfg/bin/rex-pick-workspace" --list "" "$SB/proj"; }
rows=$(pick_rows)
check "the picker lists the sessions" grep -q $'^session\tws1\t' <<<"$rows"
proj=$(cd "$SB/proj" && pwd -P)
check "the picker lists the worktrees" grep -q $'^worktree\t.*\t'"$proj"'$' <<<"$rows"
check "popup_workspace opens popup:workspace" opened popup_workspace popup:workspace

zp=$(split zsh -f -i)
sleep 0.5
type_in() {
	R send -s "$S" -b "$zp" "$1"$'\n'
	sleep 0.5
}
status_of() {
	local q
	q=$(jq -cn --arg s "$S" --arg b "$zp" \
		'{session_id: $s, block_id: $b, method: "program_status", args: {}}')
	R api call -s "$S" block.method "$q" |
		jq -r '.records[0] | "\(.state // "-") \(.app // "-") \(.msg // "-")"'
}
type_in 'autoload -Uz add-zsh-hook; noisy() { false; }; add-zsh-hook precmd noisy'
type_in "source '$REPO/dot_config/exact_zsh/rex.zsh'"
type_in 'bat() { false; }'
type_in 'sleep 0.2'
check "rex.zsh skips a short command" test "$(status_of)" = "- - -"
type_in 'REX_STATUS_MIN=0'
type_in 'FOO=1 sh -c "exit 3" --token=s3cret'
check "rex.zsh reports an error without the arguments" \
	test "$(status_of)" = "error sh sh: exit 3 after 0s"
type_in 'true'
check "rex.zsh reports done" test "$(status_of)" = "done true true: exit 0 after 0s"
type_in 'bat'
check "rex.zsh skips a full-screen program" \
	test "$(status_of)" = "done true true: exit 0 after 0s"

WATCH="$REPO/dot_claude/skills/cmd-monitor-pane/scripts/executable_watch-pane.sh"
in_sb() {
	env REX_SERVER="$SOCK" TERM_PROGRAM=rex REX_SESSION="$S" TMUX= TMPDIR="$SB/t" \
		bash "$WATCH" "$@"
}
mon=$(split bash -c 'echo ready; read -r _; echo "build: FAIL 2 tests"; read -r _; exit 3')
sleep 0.5
check "the monitor resolves a Rex block by its ID suffix" \
	test "$(in_sb --resolve "${mon: -12}")" = "$mon"
in_sb "$mon" 'FAIL' >"$SB/t/mon1" 2>&1 &
mon_pid=$!
sleep 1
R send -s "$S" -b "$mon" $'\n' >/dev/null
waited() { ! kill -0 "$1" 2>/dev/null; }
for _ in $(seq 40); do
	waited "$mon_pid" && break
	sleep 0.5
done
check "the monitor reports the settled lines that match" grep -q "build: FAIL 2 tests" "$SB/t/mon1"
in_sb "$mon" 'never-matches' >"$SB/t/mon2" 2>&1 &
mon_pid=$!
sleep 1
R send -s "$S" -b "$mon" $'\n' >/dev/null
for _ in $(seq 40); do
	waited "$mon_pid" && break
	sleep 0.5
done
check "the monitor reports the exit code" test "$(tail -1 "$SB/t/mon2")" = "pane exited 3"

window_of() {
	R api call -s "$S" session.view | jq -r --arg b "$1" \
		'.windows[] | select([.layers[].blocks[].block_id] | index($b)) | .window_id'
}
handoff() {
	env REX_SERVER="$SOCK" TERM_PROGRAM=rex REX_SESSION="$S" REX_BLOCK="$plain" TMUX= \
		"$SB/cfg/bin/rex-handoff" -- sh -c "echo ran > '$SB/t/handed'; exit 4"
}
float_id() { blocks "$S" | awk '$1 == "handoff" { print $3 }'; }
has_float() { [[ -n "$(float_id)" ]]; }
answer() {
	local f
	until5 has_float || return 0
	f=$(float_id)
	sleep 0.5
	R send -s "$S" -b "$f" "$1" >/dev/null
	sleep 0.5
	R send -s "$S" -b "$f" $'\r' >/dev/null 2>&1 || true
}
handoff >"$SB/t/h1" 2>&1 &
h_pid=$!
until5 has_float || true
check "the hand-off float opens in the agent's tab" \
	test "$(window_of "$(float_id)")" = "$(window_of "$plain")"
fstatus() {
	local q
	q=$(jq -cn --arg s "$S" --arg b "$(float_id)" \
		'{session_id: $s, block_id: $b, method: "program_status", args: {}}')
	R api call -s "$S" block.method "$q" | jq -r '.records[0].state // "-"'
}
blocked() { [[ "$(fstatus)" == blocked ]]; }
check "the hand-off float reports blocked" until5 blocked
answer $'\r'
for _ in $(seq 20); do
	waited "$h_pid" && break
	sleep 0.5
done
check "rex-handoff runs the command on Enter" file_has "$SB/t/handed" ran
check "rex-handoff prints only the exit code" test "$(cat "$SB/t/h1")" = 4
rm -f "$SB/t/handed"
handoff >"$SB/t/h2" 2>&1 &
h_pid=$!
answer $'\e'
for _ in $(seq 20); do
	waited "$h_pid" && break
	sleep 0.5
done
check "rex-handoff declines on Esc" test "$(cat "$SB/t/h2")" = 130
check "a declined hand-off runs nothing" test ! -e "$SB/t/handed"

blocker=$(split sh -c "printf '\033]7501;state=blocked:kind=question\a'; exec sleep 300")
sleep 0.5
next_json=$(R "do" -s "$S" -b "$plain" --json next_waiting)
check "next_waiting jumps to the blocked pane first" \
	test "$(jq -r '"\(.state) \(.block_id)"' <<<"$next_json")" = "blocked $blocker"

printf '#!/bin/sh\npwd > %s/t/here.cwd\n' "$SB" >"$SB/agent-here"
chmod +x "$SB/agent-here"
R "do" -s "$S" -b "$plain" agent_here "agent=$SB/agent-here" >/dev/null
check "agent_here starts the agent in a new pane" until5 test -s "$SB/t/here.cwd"

cat >"$SB/ask-agent" <<EOF
#!/bin/sh
printf '%s\n' "\$1" > $SB/t/ask.prompt
sleep 5
EOF
chmod +x "$SB/ask-agent"
R "do" -s "$S" -b "$linky" ask_pane "agent=$SB/ask-agent" >/dev/null
check "ask_pane opens popup:ask" has_label "$S" popup:ask
asked_file() {
	local f
	f=$(grep -o '/[^ ]*/pane.txt' "$SB/t/ask.prompt" 2>/dev/null) || return 1
	grep -q 'example.com' "$f"
}
check "ask_pane gives the agent the pane text" until5 asked_file

if ((fails)); then
	printf '%d failed\n' "$fails"
	exit 1
fi
echo "all passed"
