#!/usr/bin/env bash
set -euo pipefail

state="$FAKE_OP_STATE"
printf '%s\n' "$*" >>"$state/argv.log"

account=""
verb="${1:-} ${2:-}"
template="${4:-}"
while (($#)); do
	if [[ "$1" == "--account" ]]; then
		account="${2:-}"
	fi
	shift
done

base="$state/$account"
[[ -f "$base.hang" ]] && exec sleep 30
if [[ -f "$base.err" ]]; then
	cat "$base.err" >&2
	exit 1
fi

case "$verb" in
"item list") cat "$base.list.json" ;;
"item get") cat "$base.get.json" ;;
"item template") cat "$state/template-$template.json" ;;
"item create")
	if [[ ! -p /dev/stdin ]]; then
		echo "[ERROR] 2026/11/04 12:26:25 provide the item category with '--category' flag" >&2
		exit 1
	fi
	[[ -f "$state/create.hang" ]] && exec sleep 30
	[[ -f "$state/create.delay" ]] && sleep 1
	if [[ -f "$state/create.err" ]]; then
		cat "$state/create.err" >&2
		exit 1
	fi
	cat >"$state/created.json"
	cat "$state/created.json"
	;;
*)
	echo "fake op: no model for: $verb" >&2
	exit 2
	;;
esac
