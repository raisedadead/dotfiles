#!/usr/bin/env bash
set -uo pipefail

sock=${REX_GUARD_SOCK:-}
refuse() {
	printf 'rex guard: %s\n' "$1" >&2
	[[ -z "${REX_GUARD_LOG:-}" ]] || printf '%s\n' "$1" >>"$REX_GUARD_LOG"
	exit 97
}
[[ -n "$sock" && -x "${REX_GUARD_REAL:-}" ]] || refuse "no sandbox server is set"

ours() { [[ "$1" == "$sock" || "unix://$1" == "$sock" ]]; }
args=("$@") server='' autostart=''
for ((i = 0; i < ${#args[@]}; i++)); do
	case ${args[i]} in
	--) break ;;
	-S | --server) server=${args[i + 1]:-} ;;
	--server=*) server=${args[i]#*=} ;;
	-S?*) server=${args[i]#-S} server=${server#=} ;;
	--autostart | --autostart=*) autostart=1 ;;
	esac
done
if [[ -n "$server" ]]; then
	ours "$server" || refuse "-S $server is not the sandbox server"
elif [[ -n "${REX_GUARD_STRICT:-}" ]]; then
	refuse "rex $* has no -S"
elif [[ -n "${REX_SERVER:-}" ]]; then
	ours "$REX_SERVER" || refuse "REX_SERVER=$REX_SERVER is not the sandbox server"
fi

pre=()
[[ -n "$server" ]] || pre+=(-S "$sock")
[[ -n "$autostart" ]] || pre+=(--autostart=false)
exec "$REX_GUARD_REAL" ${pre[@]+"${pre[@]}"} "$@"
