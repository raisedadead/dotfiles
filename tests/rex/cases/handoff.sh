# shellcheck shell=bash
mkdir -p "$SB/t/hcwd"
h_run() {
	local out=$1
	shift
	(cd "$SB/t/hcwd" && exec env REX_GUARD_STRICT=1 REX_SERVER="$SOCK" TERM_PROGRAM=rex \
		REX_SESSION="${H_SESSION:-$S}" REX_BLOCK="${H_BLOCK:-$plain}" TMUX= \
		TMPDIR="${H_TMP:-${TMPDIR:-/tmp}}" \
		"${H_BIN:-$SB/cfg/bin/rex-handoff}" -- "$@") >"$SB/t/out.$out" 2>&1 &
	h_pid=$!
}
h_screen() { R capture -s "$S" -b "$(float_id)" 2>/dev/null; }
h_shows() { grep -qF -- "$1" <<<"$(h_screen)"; }
h_key() { R send -s "$S" -b "$(float_id)" "$1" >/dev/null 2>&1 || true; }
h_wait() {
	for _ in $(seq 40); do
		waited "$h_pid" && return 0
		sleep 0.25
	done
}
h_close() {
	local f
	f=$(float_id)
	[[ -z "$f" ]] || R block close -s "$S" "$f" >/dev/null 2>&1 || true
	until5 not has_float || true
}
h_out() { [[ "$(cat "$SB/t/out.$1")" == "$2" ]]; }
h_state() { [[ "$(fstatus)" == "$1" ]]; }
h_ready() { until5 has_float && until5 blocked; }
h_settle() { h_ready || true; }

h_run hcwd sh -c "pwd -P > '$SB/t/hpwd'"
h_settle
check "the hand-off float names the caller's directory" h_shows "t/hcwd"
h_key $'\r'
h_wait
check "the hand-off runs in the caller's directory" \
	test "$(cat "$SB/t/hpwd" 2>/dev/null)" = "$(cd "$SB/t/hcwd" && pwd -P)"
check "rex-handoff returns the code before the float closes" h_out hcwd 0
check "the finished float asks for any key" until5 h_shows "press any key to close"
check "the finished float stops reporting working" until5 h_state "done"
h_key $'\e'
check "Esc closes the finished float" until5 not has_float
h_close

h_run hrc can_haz sh
h_settle
h_key $'\r'
h_wait
check "a hand-off runs a function from ~/.zshrc" h_out hrc 0
h_close

# shellcheck disable=SC2016
h_run hleak sh -c 'test -z "${REX_HANDOFF+x}"'
h_settle
h_key $'\r'
h_wait
check "the handed command does not see REX_HANDOFF" h_out hleak 0
h_close

long=$(printf '%*s' 3000 '' | tr ' ' x)
h_run hlong sh -c "exit 0" "$long"
check "a 3000-character hand-off reports blocked" h_ready
check "a long hand-off keeps the program in the hint" h_shows "Enter: run sh"
h_indented() {
	local s
	s=$(h_screen)
	grep -q '^    xxxx' <<<"$s" && ! grep -q '^x' <<<"$s"
}
check "a long hand-off keeps its indent when it wraps" h_indented
h_close
h_wait
wide=$(printf '%*s' 1200 '' | sed 's/ /é/g')
h_run hwide sh -c "exit 0" "$wide"
check "a 1200-character UTF-8 hand-off reports blocked" h_ready
h_msg() {
	local q
	q=$(jq -cn --arg s "$S" --arg b "$(float_id)" \
		'{session_id: $s, block_id: $b, method: "program_status", args: {}}')
	R api call -s "$S" block.method "$q" | jq -r '.records[0].msg // "-"'
}
h_msg_is() { [[ "$(h_msg)" == "$1" ]]; }
check "a long UTF-8 hand-off status keeps its first 500 characters" \
	h_msg_is "Run: sh -c exit\\ 0 $(printf '%*s' 481 '' | sed 's/ /é/g')"
h_close
h_wait

h_run hahead sh -c "touch '$SB/t/hahead.ran'"
until5 has_float || true
h_key $'\r'
h_settle
sleep 0.5
check "an Enter typed as the float opens runs nothing" test ! -e "$SB/t/hahead.ran"
h_key $'ok thanks\r'
sleep 0.5
check "a stray key and Enter run nothing" test ! -e "$SB/t/hahead.ran"
check "the float says it ignored the typed keys" h_shows "Ignored typed keys"
h_key $'\e[A'
sleep 0.5
check "an arrow key does not decline" has_float
h_key $'\e'
h_wait
check "Esc declines after stray keys" h_out hahead 130
h_close

h_run hintr sh -c "touch '$SB/t/hintr.ran'"
h_settle
h_key $'\x03'
h_wait
check "Ctrl-C at the prompt reports a decline" h_out hintr 130
check "Ctrl-C at the prompt runs nothing" test ! -e "$SB/t/hintr.ran"
h_close

h_run hshut sh -c "touch '$SB/t/hshut.ran'"
h_settle
h_close
h_wait
check "closing the float at the prompt reports a decline" h_out hshut 130

h_run hstop sh -c "touch '$SB/t/hstop.ran'; exec sleep 30"
h_settle
h_key $'\r'
until5 test -e "$SB/t/hstop.ran" || true
h_key $'\x03'
h_wait
check "Ctrl-C during the command reports 130" h_out hstop 130
check "the interrupted float shows the code" until5 h_shows "exit 130"
h_close

rm -f "$SB/t/hstop.ran"
h_run hkill sh -c "touch '$SB/t/hstop.ran'; exec sleep 30"
h_settle
h_key $'\r'
until5 test -e "$SB/t/hstop.ran" || true
h_close
h_wait
check "closing the float during the command reports 130" h_out hkill 130

h_run hterm sh -c "touch '$SB/t/hterm.ran'"
h_settle
kill -TERM "$h_pid" 2>/dev/null || true
check "the float closes when the caller is stopped" until5 not has_float
h_close
h_run hdead sh -c "touch '$SB/t/hterm.ran'"
h_settle
kill -KILL "$h_pid" 2>/dev/null || true
check "the float closes when the caller is killed" until5 not has_float
h_key $'\r'
check "a hand-off whose caller died runs nothing" test ! -e "$SB/t/hterm.ran"
h_close

h_failed() {
	local rc=0
	wait "$h_pid" || rc=$?
	[[ "$rc" == 69 && ! -s "$SB/t/out.$1" ]]
}
H_SESSION=session:01a19000-0000-7000-8000-000000000000 h_run hnosess true
check "a failed open exits 69 with no output" h_failed hnosess
H_BLOCK=block:01a19000-0000-7000-8000-000000000000 h_run hnoblock true
check "a stale REX_BLOCK still opens the float" h_ready
h_key $'\e'
h_wait
h_close

h_view() { R api call -s "$S" session.view; }
h_active() { h_view | jq -r .active_window_id; }
h_focus_of() {
	h_view | jq -r --arg w "$1" '.windows[] | select(.window_id == $w) | .focused_block_id'
}
h_goto() {
	R api call -s "$S" session.focus_window \
		"$(jq -cn --arg s "$S" --arg w "$1" '{session_id: $s, window_id: $w}')" >/dev/null
}
h_float_focused() { [[ "$(h_focus_of "$1")" == "$(float_id)" ]]; }
agent_win=$(window_of "$plain")
other_win=$(R window new -s "$S" --json -- sh -c 'exec sleep 300' | jq -r .window_id)
h_goto "$other_win"
h_run hfocus true
h_settle
check "the float leaves the operator's tab active" test "$(h_active)" = "$other_win"
h_goto "$agent_win"
check "the float takes focus when the operator comes to its tab" \
	until5 h_float_focused "$agent_win"
h_key $'\e'
h_wait
h_close
h_run hhere true
h_settle
check "the float takes focus in the operator's own tab" h_float_focused "$agent_win"
h_key $'\e'
h_wait
h_close
R window close -s "$S" "$other_win" >/dev/null 2>&1 || true

h_run hpause sh -c "touch '$SB/t/hpause.ran'"
until5 has_float || true
h_key 'ok thanks'
h_settle
sleep 0.6
h_key $'\r'
sleep 0.5
check "keys typed as the float opens need a fresh Enter" test ! -e "$SB/t/hpause.ran"
check "the float names keys typed as it opens" h_shows "Ignored typed keys"
h_key 'looks good'
sleep 1
h_key $'\r'
sleep 0.5
check "typed text, a pause and Enter run nothing" test ! -e "$SB/t/hpause.ran"
check "the float still says it ignored the typed keys" h_shows "Ignored typed keys"
h_key $'yes\r'
sleep 0.6
h_key $'\r'
sleep 0.5
check "a typed reply and one more Enter run nothing" test ! -e "$SB/t/hpause.ran"
h_key $'\r'
until5 test -e "$SB/t/hpause.ran" || true
check "a second Enter after the typed keys runs it" test -e "$SB/t/hpause.ran"
h_wait
h_close

h_run hquit sh -c "exit 0"
h_settle
h_key $'\r'
h_wait
h_key $'\x03'
check "Ctrl-C closes the finished float" until5 not has_float
h_close

mkdir -p "$SB/t/htmp"
h_empty() { [[ -z "$(ls -A "$1")" ]]; }
H_TMP="$SB/t/htmp" h_run hleak sh -c "sleep 2"
h_settle
h_key $'\r'
sleep 0.5
kill -KILL "$h_pid" 2>/dev/null || true
until5 h_shows "press any key to close" || true
check "a killed caller leaves no result file" h_empty "$SB/t/htmp"
h_close

sed 's/^local a = rex.args$/error("boom")/' "$SB/cfg/bin/rex-handoff" >"$SB/t/h-broken"
chmod +x "$SB/t/h-broken"
H_BIN="$SB/t/h-broken" h_run hwaiter true
check "a failed waiter exits 69 with no output" h_failed hwaiter
check "a failed waiter closes the float" until5 not has_float
h_close

mid=$(split sh -c 'exec sleep 300')
split sh -c 'exec sleep 300' >/dev/null
h_back() {
	h_view | jq -r --arg w "$(window_of "$mid")" \
		'.windows[] | select(.window_id == $w) | "\(.focused_block_id) \(.zoomed_block_id)"'
}
h_zoomed_mid() {
	R focus -s "$S" "$mid" >/dev/null
	R zoom -s "$S" "$mid" --on >/dev/null
}
h_zoomed_mid
H_BLOCK=$mid h_run hback true
h_settle
h_key $'\r'
until5 h_shows "press any key to close" || true
sleep 0.5
h_key x
until5 not has_float || true
h_wait
check "a finished hand-off gives focus and zoom back to the caller" test "$(h_back)" = "$mid $mid"
h_zoomed_mid
H_BLOCK=$mid h_run hbackno true
h_settle
h_key $'\e'
until5 not has_float || true
h_wait
check "a declined hand-off gives focus and zoom back to the caller" test "$(h_back)" = "$mid $mid"
R zoom -s "$S" "$mid" --off >/dev/null 2>&1 || true

h_run hquote /usr/bin/printf '%s' "a b" "" "it's" $'x\ty' é '~x' 'a=~b' '#c' 'd#'
h_settle
check "the float quotes each word of the command" \
	h_shows "/usr/bin/printf %s a\\ b '' it\\'s \$'x\\ty' é \\~x a=\\~b \\#c d#"
check "the float names the program by its base name" h_shows "Enter: run printf · Esc: decline"
check "the blocked status names the quoted command" \
	h_msg_is "Run: /usr/bin/printf %s a\\ b '' it\\'s \$'x\\ty' é \\~x a=\\~b \\#c d#"
h_key $'\e'
h_wait
check "Esc declines a quoted hand-off" h_out hquote 130
h_close

h_run hkeys sh -c "IFS= read -r l; printf '%s' \"\$l\" > '$SB/t/hkeys'"
h_settle
h_key $'\r'
sleep 0.5
h_key $'typed line\r'
h_wait
check "the handed command reads the keys the operator types" \
	test "$(cat "$SB/t/hkeys" 2>/dev/null)" = "typed line"
check "rex-handoff returns the code of a command that read keys" h_out hkeys 0
h_close

h_run hfail sh -c "exit 3"
h_settle
h_key $'\r'
h_wait
check "rex-handoff prints the failed command's code" h_out hfail 3
check "a failed hand-off reports an error with its code" \
	until5 h_msg_is "exit 3: sh -c exit\\ 3"
check "a failed hand-off reports the error state" h_state error
h_close

rm -f "$SB/t/hterm.ran"
mkdir -p "$SB/t/hterm-tmp"
H_TMP="$SB/t/hterm-tmp" h_run hterm2 sh -c "touch '$SB/t/hterm.ran'"
h_settle
kill -TERM "$h_pid" 2>/dev/null || true
until5 not has_float || true
check "a stopped caller leaves no result file" until5 h_empty "$SB/t/hterm-tmp"
check "a stopped caller runs nothing" test ! -e "$SB/t/hterm.ran"
h_close
