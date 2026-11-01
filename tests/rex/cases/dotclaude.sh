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

S2=$(R new --json other -- sh -c 'exec sleep 300' | jq -r .session_id)
far=$(R split -s "$S2" --json -- bash -c 'echo ready; read -r _; echo "far: FAIL 1"; read -r _' |
	jq -r '.block_ids[0]')
sleep 0.5
check "the monitor resolves a pane in another session" \
	test "$(in_sb --resolve "${far: -12}")" = "$far"
in_sb "$far" 'FAIL' >"$SB/t/far1" 2>&1 &
far_pid=$!
sleep 1
R send -s "$S2" -b "$far" $'\n' >/dev/null
watch_until "$far_pid" 40
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
check "the monitor reports the last output of a pane that exits" \
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

lone=$(split sh -c 'exec sleep 300')
sleep 0.5
in_sb "$lone" >/dev/null 2>&1 &
lone_pid=$!
sleep 1.5
pkill -KILL -f "watch-pane[^ ]* $lone" || true
wait "$lone_pid" 2>/dev/null || true
waiters() { pgrep -f "wait .*$lone" >/dev/null; }
sleep 7
check "the waiter of a killed monitor ends" not waiters
pkill -f "wait .*$lone" 2>/dev/null || true

if command -v tmux >/dev/null; then
	TL=dcmon-$$
	tmux -L "$TL" -f /dev/null new-session -d -s mon -x 120 -y 30 \
		"bash -c 'echo ready; read -r _; echo \"tm: FAIL 3\"; read -r _'"
	tmux -L "$TL" new-window -d -t mon "sleep 300"
	tsock=$(tmux -L "$TL" display -p -t mon:0 '#{socket_path}')
	tpid=$(tmux -L "$TL" display -p -t mon:0 '#{pid}')
	in_tmux() {
		env TMUX="$tsock,$tpid,0" TERM_PROGRAM=tmux REX_SESSION= TMPDIR="$SB/t" \
			bash "$WATCH" "$@"
	}
	tid=$(in_tmux --resolve mon:0:0)
	check "the monitor resolves a tmux pane" test "${tid:0:1}" = "%"
	in_tmux "$tid" 'FAIL' >"$SB/t/tm1" 2>&1 &
	tm_pid=$!
	sleep 1
	tmux -L "$TL" send-keys -t "$tid" Enter
	watch_until "$tm_pid" 40
	check "the monitor reports a settled tmux pane" grep -q "tm: FAIL 3" "$SB/t/tm1"
	in_tmux "$tid" >"$SB/t/tm2" 2>&1 &
	tm_pid=$!
	sleep 1
	tmux -L "$TL" kill-pane -t "$tid"
	watch_until "$tm_pid" 20
	check "the monitor reports a killed tmux pane as gone" \
		test "$(tail -1 "$SB/t/tm2")" = "pane gone"
	tmux -L "$TL" kill-server 2>/dev/null || true
fi
