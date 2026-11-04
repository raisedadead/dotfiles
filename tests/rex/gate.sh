#!/usr/bin/env bash
set -euo pipefail

REPO=$(cd "$(dirname "$0")/../.." && pwd)
SB=$(mktemp -d /tmp/rexgate.test.XXXXXX)
trap 'rm -rf "$SB"' EXIT
fails=0

ok() { printf 'ok   %s\n' "$1"; }
bad() {
	printf 'FAIL %s\n' "$1"
	fails=$((fails + 1))
}
check() { if "${@:2}"; then ok "$1"; else bad "$1"; fi; }
not() { ! "$@"; }

GHOSTTY=(TERM_PROGRAM=ghostty REX_SESSION= TMUX=)
TMUX_IN_REX=(TERM_PROGRAM=rex REX_SESSION=session:x TMUX=/tmp/tmux-0/default)
REX=(TERM_PROGRAM=rex REX_SESSION=session:x TMUX=)

zshrc="$REPO/dot_config/exact_zsh/dot_zshrc"
gate_line=$(grep -F 'rex.zsh' "$zshrc")
rex_zsh_loads() {
	env "$@" ZDOTDIR="$REPO/dot_config/exact_zsh" zsh -f -c \
		"$gate_line; (( \$+functions[_rex_precmd] ))"
}
check "zshrc sources rex.zsh once" test "$(grep -c -F 'rex.zsh' "$zshrc")" = 1
check "rex.zsh parses" zsh -n "$REPO/dot_config/exact_zsh/rex.zsh"
check "rex.zsh loads in Rex" rex_zsh_loads "${REX[@]}"
check "rex.zsh stays out of Ghostty" not rex_zsh_loads "${GHOSTTY[@]}"
check "rex.zsh stays out of tmux in Rex" not rex_zsh_loads "${TMUX_IN_REX[@]}"
rex_zsh_hooks() {
	env "$@" zsh -f -c \
		"source '$REPO/dot_config/exact_zsh/rex.zsh'; (( \$+functions[_rex_precmd] ))"
}
check "rex.zsh sourced in Ghostty adds no hook" not rex_zsh_hooks "${GHOSTTY[@]}"
check "rex.zsh sourced in tmux in Rex adds no hook" not rex_zsh_hooks "${TMUX_IN_REX[@]}"
check "rex.zsh sourced in Rex adds its hook" rex_zsh_hooks "${REX[@]}"

mkdir -p "$SB/path" "$SB/home/.config/rex/bin"
cat >"$SB/path/rex" <<'EOF'
#!/bin/sh
echo '{"bindings":[{"keys":["alt+d"],"action":"pane.split.right","source":"user"}]}'
EOF
printf '#!/bin/sh\necho tmux "$@" > %s/hit\n' "$SB" >"$SB/path/tmux"
printf '#!/bin/sh\necho rex-open "$@" > %s/hit\n' "$SB" >"$SB/home/.config/rex/bin/rex-open"
printf '#!/bin/sh\necho editor "$@" > %s/hit\n' "$SB" >"$SB/editor"
chmod +x "$SB/path/rex" "$SB/path/tmux" "$SB/home/.config/rex/bin/rex-open" "$SB/editor"

rex_rows() {
	env "$@" PATH="$SB/path:$PATH" \
		python3 "$REPO/exact_dot_bin/executable_keys" --plain 2>/dev/null |
		grep -c '^rex ' || true
}
check "keys lists Rex rows in Rex" test "$(rex_rows "${REX[@]}")" -gt 0
check "keys lists no Rex rows in Ghostty" test "$(rex_rows "${GHOSTTY[@]}")" = 0
check "keys lists no Rex rows in tmux in Rex" test "$(rex_rows "${TMUX_IN_REX[@]}")" = 0

touch "$SB/notes.md"
edit_hit() {
	rm -f "$SB/hit"
	(cd "$SB" && env "$@" HOME="$SB/home" PATH="$SB/path:$PATH" EDITOR="$SB/editor" \
		bash "$REPO/exact_dot_bin/executable_mdr" --edit notes.md) >/dev/null 2>&1 || true
	cut -d' ' -f1 "$SB/hit" 2>/dev/null
}
check "mdr edit opens rex-open in Rex" test "$(edit_hit "${REX[@]}")" = rex-open
check "mdr edit runs the editor in Ghostty" test "$(edit_hit "${GHOSTTY[@]}")" = editor
check "mdr edit opens a tmux window in tmux" test "$(edit_hit "${TMUX_IN_REX[@]}")" = tmux

handoff_out() {
	env "$@" bash "$REPO/dot_config/rex/bin/executable_rex-handoff" -- \
		sh -c "touch '$SB/handed'" 2>/dev/null
}
quiet_handoff() { [[ -z "$(handoff_out "$@")" && ! -e "$SB/handed" ]]; }
check "rex-handoff does nothing in Ghostty" quiet_handoff "${GHOSTTY[@]}"
check "rex-handoff does nothing in tmux in Rex" quiet_handoff "${TMUX_IN_REX[@]}"
inner_out() {
	env "$@" REX_BLOCK= bash "$REPO/dot_config/rex/bin/executable_rex-handoff" --inner -- \
		sh -c "touch '$SB/handed'" 2>/dev/null
}
quiet_inner() { [[ -z "$(inner_out "$@" </dev/null)" && ! -e "$SB/handed" ]]; }
check "rex-handoff --inner does nothing outside a Rex pane" quiet_inner "${GHOSTTY[@]}"
check "rex-handoff --inner does nothing in tmux in Rex" quiet_inner "${TMUX_IN_REX[@]}"
check "rex-handoff --inner runs nothing without a terminal" quiet_inner "${REX[@]}"
handoff_exit() {
	local code=0
	env "$@" bash "$REPO/dot_config/rex/bin/executable_rex-handoff" -- true \
		>/dev/null 2>&1 || code=$?
	echo "$code"
}
check "rex-handoff exits 69 in Ghostty" test "$(handoff_exit "${GHOSTTY[@]}")" = 69
check "rex-handoff exits 69 in tmux in Rex" test "$(handoff_exit "${TMUX_IN_REX[@]}")" = 69
check "rex-handoff says that nothing ran outside Rex, with no usage error" \
	test "$(env "${GHOSTTY[@]}" bash "$REPO/dot_config/rex/bin/executable_rex-handoff" 2>&1)" \
	= "rex-handoff: not in Rex, so nothing ran"

unpinned() {
	# shellcheck disable=SC2016
	grep -n -e '--autostart=false' "$REPO"/dot_config/rex/bin/executable_* \
		"$REPO"/dot_config/rex/*.lua | grep -vF '${REX_SERVER:+-S "$REX_SERVER"}'
}
check "each helper gives REX_SERVER to rex as -S" not unpinned
bare_fzf() {
	grep -nE '(^|[[:space:]|(;&])fzf[[:space:]]' "$REPO"/dot_config/rex/bin/executable_* |
		grep -v executable_rex-fzf
}
check "each Rex picker runs fzf through rex-fzf" not bare_fzf
check "rex-open is on PATH as ~/.bin/rex-open" \
	test "$(cat "$REPO/exact_dot_bin/symlink_rex-open")" = ../.config/rex/bin/rex-open

recorder="$REPO/dot_config/rex/bin/executable_rex-agent-record"
record_in() {
	env CLAUDE_CODE_ENTRYPOINT=cli "$@" REX_BLOCK=block:01a19320-f71b-74f5-9125-c689b71392da \
		XDG_STATE_HOME="$SB/state" bash "$recorder" claude <<<'{"session_id":"x"}'
}
no_record() { [[ -z "$(record_in "$@")" && ! -e "$SB/state" ]]; }
check "the session recorder writes nothing in Ghostty" no_record "${GHOSTTY[@]}"
check "the session recorder writes nothing in tmux in Rex" no_record "${TMUX_IN_REX[@]}"
check "the session recorder writes nothing for a print-mode Claude" \
	no_record "${REX[@]}" CLAUDE_CODE_ENTRYPOINT=sdk-cli

OUTSIDE=(TERM_PROGRAM=ghostty REX_SESSION=session:stale REX_BLOCK=block:stale TMUX=)
no_rex_path=''
IFS=: read -ra dirs <<<"$PATH"
for d in "${dirs[@]}"; do
	[[ -x "$d/rex" ]] || no_rex_path+="${no_rex_path:+:}$d"
done
mkdir -p "$SB/with-rex"
printf '#!/bin/sh\necho "$@" >> %s/rex.hits\n' "$SB" >"$SB/with-rex/rex"
chmod +x "$SB/with-rex/rex"
WITH_REX="$SB/with-rex:$no_rex_path"
check "the outside-Rex checks run with no rex on PATH" \
	test -z "$(PATH="$no_rex_path" command -v rex)"

zsh_state() {
	# shellcheck disable=SC2016
	local show='print -l -- ${(ok)functions} ${(ok)parameters}'
	# shellcheck disable=SC2016
	show+=' $precmd_functions $preexec_functions'
	env "${OUTSIDE[@]}" PATH="$1" ZDOTDIR="$REPO/dot_config/exact_zsh" zsh -f -c "$2; $show"
}
zsh_same() {
	local base
	base=$(zsh_state "$no_rex_path" :)
	[[ "$(zsh_state "$no_rex_path" "$gate_line")" == "$base" &&
	"$(zsh_state "$WITH_REX" "$gate_line")" == "$(zsh_state "$WITH_REX" :)" ]]
}
check "outside Rex the zshrc gate changes no zsh state" zsh_same
keys_out() {
	env "${OUTSIDE[@]}" PATH="$1" python3 "$REPO/exact_dot_bin/executable_keys" --plain 2>&1 |
		grep -v '^nvim '
}
check "outside Rex keys prints the same sheet with or without rex" \
	test "$(keys_out "$WITH_REX")" = "$(keys_out "$no_rex_path")"
mdr_edit() {
	rm -f "$SB/hit"
	(cd "$SB" && env "${OUTSIDE[@]}" HOME="$SB/home" PATH="$1" EDITOR="$SB/editor" \
		bash "$REPO/exact_dot_bin/executable_mdr" --edit notes.md) >/dev/null 2>&1 || true
	cat "$SB/hit" 2>/dev/null
}
check "outside Rex mdr --edit runs the editor with or without rex" \
	test "$(mdr_edit "$WITH_REX")" = "$(mdr_edit "$no_rex_path")"
check "outside Rex mdr --edit runs the editor itself" \
	test "$(mdr_edit "$WITH_REX" | cut -d' ' -f1)" = editor
check "outside Rex no shared file runs rex" test ! -e "$SB/rex.hits"

if ((fails)); then
	printf '%d failed\n' "$fails"
	exit 1
fi
echo "all passed"
