# shellcheck shell=bash disable=SC2154
watch_until() {
	local pid=$1 n=$2
	for _ in $(seq "$n"); do
		waited "$pid" && return 0
		sleep 0.5
	done
	kill "$pid" 2>/dev/null
	return 1
}
saw_then_stop() {
	local pid=$1 file=$2 text=$3 id=$4
	for _ in $(seq 40); do
		grep -q "$text" "$file" && break
		sleep 0.5
	done
	pkill -TERM -f "watch-pane[^ ]* $id( |\$)" 2>/dev/null || true
	wait "$pid" 2>/dev/null || true
}

S2=$(R new --json other -- sh -c 'exec sleep 300' | jq -r .session_id)
far=$(R split -s "$S2" --json -- bash -c 'echo ready; read -r _; echo "far: FAIL 1"; read -r _' |
	jq -r '.block_ids[0]')
sleep 0.5
check "the monitor resolves a pane in another session" \
	test "$(in_sb --resolve "${far: -12}")" = "$far"
strict_resolve() { REX_GUARD_STRICT=1 REX_GUARD_LOG='' in_sb --resolve "$1" 2>/dev/null; }
check "the monitor passes REX_SERVER to rex as -S" \
	test "$(strict_resolve "${far: -12}")" = "$far"
in_sb "$far" 'FAIL' >"$SB/t/far1" 2>&1 &
far_pid=$!
sleep 1
R send -s "$S2" -b "$far" $'\n' >/dev/null
saw_then_stop "$far_pid" "$SB/t/far1" "far: FAIL 1" "$far"
check "the monitor reports a pane in another session" grep -q "far: FAIL 1" "$SB/t/far1"
far_state() { compgen -G "$SB/t/watch-pane-$(id -u)/rex.*-${far#block:}" >/dev/null; }
in_sb --resolve "$plain" >/dev/null
check "a resolve keeps the state of a live pane in another session" far_state

shut=$(split sh -c 'exec sleep 300')
sleep 0.5
in_sb "$shut" >"$SB/t/shut" 2>&1 &
shut_pid=$!
sleep 1
R block close -s "$S" "$shut" >/dev/null 2>&1
watch_until "$shut_pid" 20
check "the monitor reports a closed pane as gone" test "$(tail -1 "$SB/t/shut")" = "pane gone"

last=$(split bash -c 'echo start; sleep 4; echo "error: disk full"; sleep 5; exit 2')
sleep 0.5
in_sb "$last" 'never-matches' >"$SB/t/last" 2>&1 &
last_pid=$!
watch_until "$last_pid" 40
check "the monitor reports the output it read before a pane exits" \
	grep -q "error: disk full" "$SB/t/last"
check "the monitor then reports the exit code" test "$(tail -1 "$SB/t/last")" = "pane exited 2"

label_as() {
	R api call -s "$1" session.set_block_label \
		"$(jq -cn --arg b "$2" --arg l "$3" '{block_id: $b, label: $l}')" >/dev/null
}
mine=$(split sh -c 'exec sleep 300')
label_as "$S" "$mine" dup
label_as "$S2" "$far" dup
sleep 0.3
check "a label resolves in the current session first" \
	test "$(in_sb --resolve dup 2>&1)" = "$mine"
twin=$(split sh -c 'exec sleep 300')
label_as "$S" "$twin" dup
sleep 0.3
check "an ambiguous label says so" grep -q ambiguous <<<"$(in_sb --resolve dup 2>&1)"

late=$(split sh -c 'sleep 20; exit 5')
sig=$(split sh -c 'sleep 2; kill -9 $$')
lone=$(split sh -c 'exec sleep 300')
sleep 0.5
in_sb "$late" 'never-matches' >"$SB/t/late" 2>&1 &
late_pid=$!
in_sb "$sig" 'never-matches' >"$SB/t/sig" 2>&1 &
sig_pid=$!
in_sb "$lone" >/dev/null 2>&1 &
lone_pid=$!
sleep 1.5
kill -KILL "$(pgrep -o -f "watch-pane[^ ]* $lone")"
wait "$lone_pid" 2>/dev/null || true
waiters() { pgrep -f "wait .*$lone" >/dev/null; }
sleep 17
check "the waiter of a killed monitor ends" not waiters
pkill -f "wait .*$lone" 2>/dev/null || true
watch_until "$sig_pid" 4
check "the monitor names the signal that killed a pane" \
	test "$(tail -1 "$SB/t/sig")" = "pane exited -1 (signal: killed)"
watch_until "$late_pid" 30
check "the monitor reports an exit after a re-armed wait" \
	test "$(tail -1 "$SB/t/late")" = "pane exited 5"

if command -v tmux >/dev/null; then
	TL=dcmon-$$
	tmux -L "$TL" -f /dev/null new-session -d -s mon -x 120 -y 30 \
		"bash -c 'echo ready; read -r _; echo \"tm: FAIL 3\"; read -r _'"
	tmux -L "$TL" new-window -d -t mon "sleep 300"
	tsock=$(tmux -L "$TL" display -p -t mon:0 '#{socket_path}')
	tpid=$(tmux -L "$TL" display -p -t mon:0 '#{pid}')
	in_tmux() {
		env TMUX="$tsock,$tpid,0" TERM_PROGRAM=tmux REX_SESSION= TMPDIR="$SB/t" \
			bun --no-env-file --config=/dev/null "$WATCH" "$@"
	}
	tid=$(in_tmux --resolve mon:0:0)
	check "the monitor resolves a tmux pane" test "${tid:0:1}" = "%"
	in_tmux "$tid" 'FAIL' >"$SB/t/tm1" 2>&1 &
	tm_pid=$!
	sleep 1
	tmux -L "$TL" send-keys -t "$tid" Enter
	saw_then_stop "$tm_pid" "$SB/t/tm1" "tm: FAIL 3" "$tid"
	check "the monitor reports a matching tmux line" grep -q "tm: FAIL 3" "$SB/t/tm1"
	in_tmux "$tid" 'never-matches' >"$SB/t/tm-lost" 2>&1 &
	tm_pid=$!
	sleep 1
	rm -rf "$SB/t/watch-pane-$(id -u)"/*-"${tid#%}"
	watch_until "$tm_pid" 20
	check "the monitor reports a lost state folder" \
		test "$(tail -1 "$SB/t/tm-lost")" = "watch failed: the state folder was removed; resolve again"
	in_tmux "$tid" >"$SB/t/tm2" 2>&1 &
	tm_pid=$!
	sleep 1
	tmux -L "$TL" kill-pane -t "$tid"
	watch_until "$tm_pid" 20
	check "the monitor reports a killed tmux pane as gone" \
		test "$(tail -1 "$SB/t/tm2")" = "pane gone"
	tmux -L "$TL" kill-server 2>/dev/null || true
fi

SETTINGS="$DOTCLAUDE/.settings.managed.json"
BARE=/usr/bin:/bin:/usr/sbin:/sbin
rex_hooks() {
	jq -r --arg e "$1" '.hooks[$e][]?.hooks[].command | select(test("rex"))' "$SETTINGS"
}
mkdir -p "$SB/hook-home/.config/rex/bin" "$SB/bare-home"
install -m 755 "$SRC/bin/executable_rex-agent-record" \
	"$SB/hook-home/.config/rex/bin/rex-agent-record"
U9=0a1b2c3d-0000-4000-8000-000000000009
hook_in() {
	env -i HOME="$1" PATH="$2" "${@:4}" /bin/sh -c "$3" 2>&1 \
		<<<"{\"session_id\":\"$U9\",\"reason\":\"prompt_input_exit\"}"
}
quiet_hooks() {
	local line out home n=0
	! env PATH="$BARE" sh -c 'command -v rex' >/dev/null || return 1
	while IFS= read -r line; do
		n=$((n + 1))
		for home in "$SB/hook-home" "$SB/bare-home"; do
			out=$(hook_in "$home" "$BARE" "$line") || return 1
			[[ -z "$out" ]] || return 1
		done
	done < <(rex_hooks SessionStart && rex_hooks SessionEnd)
	((n == 3))
}
check "with no rex on PATH and outside Rex, the Rex hook lines exit 0 silently" quiet_hooks
ended=$(split sh -c 'exec sleep 300')
record_for "$ended" "$U9"
end_hook() {
	hook_in "$SB/hook-home" "/opt/homebrew/bin:$BARE" "$(rex_hooks SessionEnd)" \
		TERM_PROGRAM=rex REX_SESSION="$S" REX_BLOCK="$ended" CLAUDE_CODE_ENTRYPOINT=cli \
		XDG_STATE_HOME="$SB/state-home" >/dev/null
	test ! -e "$(rec "$ended")"
}
check "the SessionEnd hook removes the record of a session the operator exits" end_hook

mkdir -p "$SB/stub-rex"
printf '#!/bin/sh\necho REX-STUB "$@"\n' >"$SB/stub-rex/rex"
chmod +x "$SB/stub-rex/rex"
start_line() {
	jq -r '.hooks.SessionStart[].hooks[].command | select(test("session-start"))' "$SETTINGS"
}
start_says() {
	hook_in "$SB/bare-home" "$SB/stub-rex:$BARE" "$(start_line)" "$@"
}
gated_start() {
	[[ -z "$(start_says TERM_PROGRAM=tmux TMUX=/tmp/x,1,0 REX_SESSION=x REX_BLOCK="$plain")" ]] &&
		[[ -z "$(start_says TERM_PROGRAM=ghostty REX_SESSION=x REX_BLOCK="$plain")" ]] &&
		grep -q REX-STUB <<<"$(start_says TERM_PROGRAM=rex REX_SESSION=x REX_BLOCK="$plain")"
}
check "the Rex session-start hook speaks only in a Rex pane outside tmux" gated_start
