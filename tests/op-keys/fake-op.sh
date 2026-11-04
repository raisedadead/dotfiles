#!/usr/bin/env bash
set -euo pipefail

state="$FAKE_OP_STATE"
printf '%s\n' "$*" >>"$state/argv.log"

account=""
verb="${1:-} ${2:-}"
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
*)
	echo "fake op: no model for: $verb" >&2
	exit 2
	;;
esac
