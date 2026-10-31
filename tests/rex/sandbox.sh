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

rex server run --listen "$SOCK" --state-dir "$SB/state" \
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

if ((fails)); then
	printf '%d failed\n' "$fails"
	exit 1
fi
echo "all passed"
