# shellcheck shell=bash
# shellcheck disable=SC2154

alone() { fails_with "$S" "no other agent is waiting" -b "$blocker" next_waiting; }
check "next_waiting says so when no other agent waits" alone
agent_pane() {
	split bash -c "printf '\033]7501;state=$1:app=claude-code\a'; exec -a claude sleep 300"
}
nap() { sleep 0.3; }
w1=$(agent_pane blocked) && nap
w2=$(agent_pane blocked) && nap
w3=$(agent_pane blocked) && nap
w4=$(agent_pane "done") && nap
press() {
	local out
	out=$(R "do" -s "$1" -b "$2" --json next_waiting 2>/dev/null || true)
	jq -r '"\(.session_id // "x") \(.block_id // "x")"' <<<"${out:-"{}"}"
}
visits() {
	local s=$S at=$1 out='' r
	for _ in $(seq "$2"); do
		r=$(press "$s" "$at")
		s=${r% *} at=${r#* }
		out+="$at "
		[[ "$at" == "${3-}" || "$at" == x ]] && break
	done
	echo "$out"
}
seen=$(visits "$plain" 6)
check "next_waiting visits every waiting agent in order, then wraps" \
	test "$seen" = "$blocker $w1 $w2 $w3 $w4 $blocker "

s3_json=$(R new --json t3 -- sh -c 'exec sleep 300')
S3=$(jq -r .session_id <<<"$s3_json")
s3_first=$(jq -r '.initial_windows[0].block_ids[0]' <<<"$s3_json")
split3() { R split -s "$S3" --json -- "$@" | jq -r '.block_ids[0]'; }
make_pane=$(split3 sh -c "printf '\033]7501;state=error:app=make\a'; exec sleep 300")
gone=$(split3 sh -c "printf '\033]7501;state=done:app=claude-code\a'; exec sleep 300")
hidden=$(split3 bash -c \
	"printf '\033]7501;state=error:app=claude-code\a'; exec -a claude sleep 300")
sleep 0.5
R api call -s "$S3" session.detach_block \
	"$(jq -cn --arg s "$S3" --arg b "$hidden" '{session_id: $s, block_id: $b}')" >/dev/null
R api call -s "$S" session.focus_block \
	"$(jq -cn --arg s "$S" --arg b "$plain" '{session_id: $s, block_id: $b}')" >/dev/null
cross=$(R "do" -s "$S3" -b "$s3_first" --json next_waiting 2>&1 || true)
focused() {
	R api call -s "$S" session.view |
		jq -r '(.windows | INDEX(.window_id))[.active_window_id].focused_block_id'
}
check "next_waiting focuses an agent in another session" test "$(focused)" = "$blocker"
check "next_waiting asks the app to show that session" grep -q "not delivered" <<<"$cross"
round=$(visits "$blocker" 20 "$blocker")
check "next_waiting goes round the waiting agents" \
	test "$round" = "$w1 $w2 $w3 $w4 $blocker "
check "next_waiting skips a shell's long-command record" not grep -q "$make_pane" <<<"$round"
check "next_waiting skips a claude-code record once claude is gone" \
	not grep -q "$gone" <<<"$round"
check "next_waiting skips a detached pane" not grep -qE "$hidden|(^| )x " <<<"$round"

printf '#!/bin/sh\nenv > %s/t/ask.env\n' "$SB" >"$SB/env-agent"
chmod +x "$SB/env-agent"
split "$SB/cfg/bin/rex-ask" "$linky" "$SB/env-agent" >/dev/null
check "rex-ask tells the agent not to record its session" \
	until5 file_has "$SB/t/ask.env" '^REX_AGENT_RECORD=0$'
check "the prompt names the line count" \
	grep -qE 'holds the last [0-9]+ non-blank lines' "$SB/t/agent.args"
check "the prompt path has no double slash" not grep -q '//rex-ask' "$SB/t/agent.args"

asks_before=$(wc -l <"$SB/t/agent.args")
empty=$(split sh -c 'exec sleep 300')
sleep 0.5
says_empty() {
	local id rc=1
	id=$(R "do" -s "$S" -b "$empty" --json ask_pane 2>/dev/null | jq -r '.block_id // empty')
	[[ -n "$id" ]] || return 1
	for _ in $(seq 30); do
		grep -qF "The pane is empty" <<<"$(R capture -s "$S" -b "$id" 2>/dev/null)" &&
			rc=0 && break
		sleep 0.1
	done
	R block close -s "$S" "$id" >/dev/null 2>&1
	return "$rc"
}
check "ask_pane on an empty pane says so" says_empty
check "ask_pane on an empty pane starts no agent" \
	test "$(wc -l <"$SB/t/agent.args")" = "$asks_before"

agent_dir="$SB/state-home/rex/agents"
recorder="$SRC/bin/executable_rex-agent-record"
quiet_rec=$(split sh -c 'exec sleep 300')
REX_AGENT_RECORD=0 record_for "$quiet_rec" 0a1b2c3d-0000-4000-8000-000000000010
check "the recorder writes nothing when told not to" test ! -e "$(rec "$quiet_rec")"

U5=0a1b2c3d-0000-4000-8000-000000000005
end_for() {
	env TERM_PROGRAM=rex REX_SESSION="$S" REX_BLOCK="$1" TMUX= CLAUDE_CODE_ENTRYPOINT=cli \
		XDG_STATE_HOME="$SB/state-home" bash "$recorder" --end \
		<<<"{\"session_id\":\"$2\",\"reason\":\"$3\"}"
}
ender=$(split sh -c 'exec sleep 300')
record_for "$ender" "$U5"
end_for "$ender" "$U5" other
check "a session that ends for another reason keeps its record" test -e "$(rec "$ender")"
end_for "$ender" 0a1b2c3d-0000-4000-8000-000000000006 prompt_input_exit
check "the end of another session keeps the record" test -e "$(rec "$ender")"
end_for "$ender" "$U5" prompt_input_exit
check "a session the operator exits removes its record" test ! -e "$(rec "$ender")"

stale="$agent_dir/0a1b2c3d-0000-4000-8000-0000000000ff.json"
echo '{}' >"$stale"
touch -t 202001010000 "$stale"
record_for "$ender" "$U5"
check "the recorder prunes a record older than 30 days" test ! -e "$stale"

in_pane=$(split sh -c "echo '{\"session_id\":\"$U5\"}' |
	CLAUDE_CODE_ENTRYPOINT=cli '$SB/cfg/bin/rex-agent-record' claude; exec sleep 300")
check "a recorder in a pane writes into the sandbox" until5 test -e "$(rec "$in_pane")"

U7=0a1b2c3d-0000-4000-8000-000000000007
pop=$(R split -s "$S" --json --label popup:ask -- env PATH="$SB/fakebin:$PATH" zsh -f -i |
	jq -r '.block_ids[0]')
sleep 0.5
record_for "$pop" "$U7"
sleep 1
resume_json=$(R "do" -s "$S" --json agents_resume)
sleep 1
check "agents_resume types nothing into a popup" not grep -q "$U7" "$SB/t/resumed"
check "agents_resume reports a count" test "$(jq -r .count <<<"$resume_json")" = 0

U8=0a1b2c3d-0000-4000-8000-000000000008
far=$(split3 env PATH="$SB/fakebin:$PATH" zsh -f -i)
sleep 0.5
record_for "$far" "$U8"
sleep 1
R "do" -s "$S" agents_resume >/dev/null
check "agents_resume resumes a pane in another session" \
	until5 file_has "$SB/t/resumed" "claude --resume $U8"
