#!/usr/bin/env bash
# shellcheck shell=bash

set -uo pipefail

FNM_DEFAULT="${FNM_DEFAULT:-$HOME/.local/share/fnm/aliases/default}"
CAVEMEM_HOME="${CAVEMEM_HOME:-$HOME/.cavemem}"
BSQL_MIN_MAJOR=12

node="$FNM_DEFAULT/bin/node"
bin="$FNM_DEFAULT/bin/cavemem"
modules="$FNM_DEFAULT/lib/node_modules"
xenova="$modules/@xenova/transformers"
rc=0

problem() {
	printf '%s %s\n' "$1" "$2"
	rc=1
}

json_field() {
	"$node" -e 'try { const v = process.argv[2].split(".").reduce((o, k) => o?.[k], JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))); console.log(v ?? "") } catch { console.log("") }' "$1" "$2" 2>/dev/null
}

if [[ ! -x "$bin" ]]; then
	problem missing "cavemem is missing on the fnm default node"
	exit 1
fi
if ! "$node" "$bin" --version >/dev/null 2>&1; then
	problem start "cavemem does not start on the fnm default node"
	exit 1
fi

if ! out=$(printf '%s' '{"session_id":"cavemem-health","cwd":"/tmp"}' |
	timeout 5 "$node" "$bin" hook run session-end --ide claude-code 2>&1) || [[ "$out" != *'"ok":true'* ]]; then
	problem hook "cavemem hook fails"
fi

major=$(json_field "$modules/cavemem/node_modules/better-sqlite3/package.json" version)
major=${major%%.*}
if [[ ! "$major" =~ ^[0-9]+$ ]]; then
	problem bsql "better-sqlite3 is missing under cavemem"
elif ((major < BSQL_MIN_MAJOR)); then
	problem bsql "cavemem better-sqlite3 ${major}.x does not build on Node 26 and aborts in GC (WiseLibs/better-sqlite3#1515)"
fi

[[ "$(json_field "$CAVEMEM_HOME/settings.json" embedding.provider)" == "none" ]] && exit "$rc"

if [[ ! -d "$xenova" ]]; then
	problem embedder "@xenova/transformers is missing (undeclared cavemem dependency)"
elif ! timeout 30 "$node" --input-type=module -e 'await import(process.argv[1])' "$xenova/src/transformers.js" >/dev/null 2>&1; then
	problem embedder "@xenova/transformers does not load (sharp has no native build)"
fi

pid=$(cat "$CAVEMEM_HOME/worker.pid" 2>/dev/null)
if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
	dim=$(json_field "$CAVEMEM_HOME/worker.state.json" dim)
	[[ "$dim" =~ ^[1-9][0-9]*$ ]] || problem worker "cavemem worker $pid runs without an embedder"
fi

exit "$rc"
