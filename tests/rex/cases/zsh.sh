# shellcheck shell=bash

REX_ZSH="$REPO/dot_config/exact_zsh/rex.zsh"
printf '[alias]\n\tlg = log --oneline\n\tup = pull --rebase\n' >"$SB/t/gitconfig"

decode_report() {
	[[ $1 == *$'\e]7501;'* ]] || {
		echo none
		return
	}
	local body=${1#*$'\e]7501;'} st=- app=- msg=- kv
	local -a kvs
	IFS=: read -ra kvs <<<"${body%$'\e\\'}"
	for kv in "${kvs[@]}"; do
		case $kv in
		state=*) st=${kv#state=} ;;
		app=*) app=${kv#app=} ;;
		msg=*) msg=$(base64 -d <<<"${kv#msg=}") ;;
		esac
	done
	echo "$st $app $msg"
}
report_for() {
	local out
	# shellcheck disable=SC2016
	out=$(env TERM_PROGRAM=rex REX_SESSION="$S" TMUX= GIT_CONFIG_GLOBAL="$SB/t/gitconfig" \
		zsh -f -c 'source "$1"; REX_STATUS_MIN=1
			_rex_cmd=$4 _rex_t0=$(( EPOCHREALTIME - $3 ))
			(exit $2); _rex_precmd' zsh "$REX_ZSH" "$1" "$2" "$3")
	decode_report "$out"
}
reports() { test "$(report_for 0 3 "$1")" = "done ${2:-make} ${2:-make}: exit 0 after 3s"; }
silent() { test "$(report_for "${2:-0}" 3 "$1")" = none; }

check "rex.zsh names the program after a wrapper with options" reports 'nice -n 5 make'
check "rex.zsh names the program after caffeinate" reports 'caffeinate -i make'
check "rex.zsh names the last command of a list" reports 'cd /tmp && make'
check "rex.zsh names the head of a pipeline" reports 'make 2>&1 | tee build.log'
check "rex.zsh names the program in a subshell" reports $'(\n\tmake all\n)'
check "rex.zsh names the program in a brace group" reports $'{\n\tmake\n\tmake test\n}'
check "rex.zsh names the program after a [[ ]] test" reports '[[ -f x ]] && make'
check "rex.zsh names a git command that does not page" reports 'git push' git
check "rex.zsh names a git alias that does not page" reports 'git up' git
check "rex.zsh names a non-interactive docker run" reports 'docker run --rm img make' docker
check "rex.zsh names a gh command that watches" reports 'gh pr checks --watch' gh
check "rex.zsh names a script run by node" reports 'node build.js' node
check "rex.zsh drops control characters from the name" reports "\$'\\e'make"
check "rex.zsh keeps the app inside the app character set" \
	test "$(report_for 0 3 'make,all')" = "done makeall make,all: exit 0 after 3s"
check "rex.zsh reports an error code" \
	test "$(report_for 2 3 make)" = "error make make: exit 2 after 3s"
check "rex.zsh formats minutes" \
	test "$(report_for 0 75 make)" = "done make make: exit 0 after 1m 15s"
check "rex.zsh formats hours" \
	test "$(report_for 0 3725 make)" = "done make make: exit 0 after 1h 2m 5s"
check "rex.zsh skips a command under the threshold" test "$(report_for 0 0 make)" = none
check "rex.zsh skips env with a pager" silent 'env FOO=1 less x'
check "rex.zsh skips sudo with an editor" silent 'noglob sudo -u root nvim x'
check "rex.zsh skips a quoted pager" silent '\less x'
check "rex.zsh skips a pager at the end of a pipeline" silent 'make | less'
check "rex.zsh skips git log behind git options" silent "git -c core.pager='less -+F' log"
check "rex.zsh skips a git alias that pages" silent 'git lg'
check "rex.zsh skips git commit" silent 'git commit'
check "rex.zsh skips an interactive rebase" silent 'git rebase -i main'
check "rex.zsh skips an interactive docker run" silent 'docker run --rm -it img'
check "rex.zsh skips gh dash" silent 'gh dash'
check "rex.zsh skips a node REPL" silent 'node'
check "rex.zsh skips a sudo shell" silent 'sudo -s'
check "rex.zsh skips the ca function" silent 'ca'
check "rex.zsh skips fg" silent 'fg %1'
check "rex.zsh skips a job resumed by its number" silent '%1'
check "rex.zsh skips a bare [[ ]] test" silent '[[ -f x ]]'
check "rex.zsh skips a stopped job" silent 'sleep 40' 146
check "rex.zsh skips an interrupted command" silent 'make' 130
check "rex.zsh skips a closed pipe" silent 'make' 141
check "rex.zsh names each program of a failed list" \
	test "$(report_for 2 3 'make && echo ok')" = "error make make && echo: exit 2 after 3s"
check "rex.zsh does not blame the first program for a later failure" \
	test "$(report_for 1 3 'sleep 3 && false')" = "error sleep sleep && false: exit 1 after 3s"
check "rex.zsh names one failed program alone" \
	test "$(report_for 1 3 'make 2>&1 | tee log')" = "error make make: exit 1 after 3s"
check "rex.zsh names the program before a fallback" reports 'make || true'
check "rex.zsh names the program before a notifier" reports 'make; say done'
check "rex.zsh names the program between cd commands" \
	reports 'cd x && just update && cd -' just
check "rex.zsh names the program behind a heredoc" \
	reports $'kubectl apply -f - <<EOF\napiVersion: v1\nkind: Pod\nEOF' kubectl
check "rex.zsh ignores a pager word in a heredoc" reports $'make <<EOF\nless\nEOF'
check "rex.zsh ignores a tab-indented quoted heredoc" \
	reports $'make <<-\'EOF\'\n\tless\n\tEOF'
check "rex.zsh reads the line after a heredoc" silent $'make <<A\nless\nA\nnvim x'
check "rex.zsh names a shell fed by a pipe" \
	reports 'curl -fsSL https://example.com/install.sh | sh' curl
check "rex.zsh names a shell fed by a file" reports 'zsh < build.zsh' zsh
check "rex.zsh names a shell fed by a heredoc" reports $'sh <<EOF\nmake\nEOF' sh
check "rex.zsh names a pager inside a pipeline" reports 'bat a | python3 load.py' bat
check "rex.zsh names git log inside a pipeline" reports 'git log --format=%H | wc -l' git
check "rex.zsh names a commit with a message" reports 'git commit -am wip' git
check "rex.zsh names a commit that keeps its message" \
	reports 'git commit --amend --no-edit' git
check "rex.zsh skips a commit that rewords" silent 'git commit --fixup=reword:HEAD'
check "rex.zsh names the program after a sudo option cluster" reports 'sudo -iu root make'
check "rex.zsh skips wt switch with an agent" silent 'wt switch -x claude main'
check "rex.zsh skips any command that runs an agent" silent 'op run -- claude'
pickers() {
	local p
	for p in 'wt switch' mo spf keys _mrgsh_ssh _mrgsh_rkh cdi irb ruby; do
		silent "$p" || return 1
	done
}
check "rex.zsh skips the pickers and REPLs" pickers

mkdir -p "$SB/zdot-status" "$SB/zstub"
for stub in claude lazygit; do
	printf '#!/bin/sh\necho %s >> %s/t/zstub.ran\n' "$stub" "$SB" >"$SB/zstub/$stub"
	chmod +x "$SB/zstub/$stub"
done
{
	# shellcheck disable=SC2016
	echo 'can_haz() { whence -p "$1" >/dev/null 2>&1 }'
	echo 'compdef() { : }'
	echo "source '$REPO/dot_config/exact_zsh/alias.zsh'"
	echo "ZDOTDIR='$REPO/dot_config/exact_zsh'"
	grep -F 'rex.zsh' "$REPO/dot_config/exact_zsh/dot_zshrc"
	echo 'REX_STATUS_MIN=0'
} >"$SB/zdot-status/.zshrc"
zr=$(split env PATH="$SB/zstub:$PATH" ZDOTDIR="$SB/zdot-status" zsh -i)
sleep 1
zin() {
	R send -s "$S" -b "$zr" "$1"$'\n' >/dev/null
	sleep 0.5
}
zstatus() {
	local q
	q=$(jq -cn --arg s "$S" --arg b "$zr" \
		'{session_id: $s, block_id: $b, method: "program_status", args: {}}')
	R api call -s "$S" block.method "$q" |
		jq -r '.records[0] | "\(.state // "-") \(.app // "-") \(.msg // "-")"'
}
zin "whence -p claude lazygit > '$SB/t/zwhich'"
stubbed() {
	[[ "$(cat "$SB/t/zwhich" 2>/dev/null)" == "$SB/zstub/claude"$'\n'"$SB/zstub/lazygit" ]]
}
check "the zsh pane resolves claude and lazygit to stubs" until5 stubbed
if stubbed; then
	zin 'sh -c "exit 4"'
	base='error sh sh: exit 4 after 0s'
	check "rex.zsh reports in a pane with the real aliases" test "$(zstatus)" = "$base"
	zin ca
	base='- - -'
	check "rex.zsh clears its record when the next command starts" \
		test "$(zstatus)" = "$base"
	zin g
	ran() { [[ "$(tr '\n' ' ' <"$SB/t/zstub.ran" 2>/dev/null)" == "claude lazygit " ]]; }
	check "the ca function and the g alias ran the stubs" until5 ran
	check "rex.zsh skips the ca function and the g alias" test "$(zstatus)" = "$base"
	zin "sh -c 'sleep 3; touch $SB/t/zfg'"
	R send -s "$S" -b "$zr" $'\x1a' >/dev/null
	sleep 0.5
	check "rex.zsh skips a command stopped with Ctrl+Z" test "$(zstatus)" = "$base"
	zin "jobs > '$SB/t/zjobs'"
	check "Ctrl+Z stopped the job" until5 file_has "$SB/t/zjobs" 'suspended.*sleep 3'
	check "rex.zsh reports the command after a cleared record" \
		test "$(zstatus)" = 'done jobs jobs: exit 0 after 0s'
	zin fg
	check "fg ran the stopped job to its end" until5 test -e "$SB/t/zfg"
	sleep 0.5
	check "rex.zsh skips a job resumed by fg" test "$(zstatus)" = "$base"
	zin "jobs > '$SB/t/zjobs2'"
	check "fg left no stopped job" until5 test -e "$SB/t/zjobs2"
	check "the jobs list is empty after fg" not test -s "$SB/t/zjobs2"
	zin 'sleep 30'
	R send -s "$S" -b "$zr" $'\x03' >/dev/null
	sleep 0.5
	check "rex.zsh skips a command ended by Ctrl+C" test "$(zstatus)" = "$base"
	zin '( sh -c "exit 5" )'
	check "rex.zsh names the program in a typed subshell" \
		test "$(zstatus)" = "error sh sh: exit 5 after 0s"
fi

skip_home="$SB/t/handoff-home"
mkdir -p "$skip_home"
# shellcheck disable=SC2016
env -i HOME="$skip_home" PATH="$PATH" REX_HANDOFF=1 ZDOTDIR="$REPO/dot_config/exact_zsh" \
	ZPLUGDIR="$skip_home/plugins" \
	zsh -f -c 'source "$ZDOTDIR/plugins.zsh"; source "$ZDOTDIR/completions.zsh"' \
	>"$SB/t/handoff-skip" 2>&1 || true
check "a hand-off shell loads the completions" test -s "$skip_home/.zcompdump"
check "a hand-off shell skips the plugin install" test ! -e "$skip_home/plugins"
check "a hand-off shell skips the completion rebuild" \
	test ! -e "$skip_home/.cache/zsh/completion-state"
