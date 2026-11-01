launchd_env() {
	R "do" -s "$S" --json t_env | jq -e --arg home "$HOME" '
		.PATH == "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" and
		.SHELL == "/opt/homebrew/bin/zsh" and .HOME == $home and
		([.LANG, .LC_ALL, .TERM, .TERM_PROGRAM, .ZDOTDIR, .XDG_CONFIG_HOME,
			.REX_SESSION, .REX_BLOCK, .SANDBOX_CALLER_ONLY] | all(. == null))' \
		>/dev/null
}
check "the sandbox server has the launchd environment" launchd_env

refuses() {
	local out
	out=$(REX_GUARD_LOG='' "$@" 2>&1) && return 1
	grep -qF "$GUARD_SAYS" <<<"$out"
}
refused() {
	local far=unix:///tmp/rex-elsewhere.sock
	GUARD_SAYS='is not the sandbox server'
	refuses env REX_SERVER="$far" rex ls &&
		refuses rex -S "$far" ls &&
		refuses rex "-S$far" ls &&
		refuses rex "-S=$far" ls &&
		refuses rex "--server=$far" ls &&
		refuses rex ls --server "$far"
}
check "the rex guard refuses another server" refused

strict() {
	GUARD_SAYS='has no -S'
	refuses env REX_GUARD_STRICT=1 rex ls &&
		REX_GUARD_STRICT=1 rex -S "$SOCK" ls >/dev/null
}
check "the strict rex guard refuses a call with no -S" strict
