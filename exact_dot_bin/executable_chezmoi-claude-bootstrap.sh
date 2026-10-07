#!/usr/bin/env bash
# chezmoi-claude-bootstrap — fresh-machine setup for the Claude Code rig.
#
# Idempotent. Run after `chezmoi init --apply` (clone + apply). Installs what
# chezmoi cannot: the cavemem package, the MCP merge, and the plugins.
#
# Steps (each idempotent — re-runs are safe):
#   1. cavemem  — cavemem-health.sh, then install or repair on fnm-default node
#   2. MCP reconcile — chezmoi apply ~/.claude.json
#   3. plugins  — claude plugin install for each enabledPlugins entry
#   4. verify   — ~/.bin/chezmoi-claude-doctor.sh (5 phases)
#
# Usage:
#   chezmoi-claude-bootstrap.sh             # run all steps
#   chezmoi-claude-bootstrap.sh --check     # report missing pieces, no install
#   chezmoi-claude-bootstrap.sh --skip NAME # skip step (cavemem|mcp|plugins|verify)
#   chezmoi-claude-bootstrap.sh --only NAME # run only one step

# step_* dispatch and helper functions are invoked indirectly — silence the
# whole-file SC2329 false positive.
# shellcheck shell=bash disable=SC2329

set -uo pipefail

PRIV_SOURCE="${PRIV_SOURCE:-$HOME/.dotfiles}"
SETTINGS="${SETTINGS:-$PRIV_SOURCE/dot_claude/settings.json}"

DIM=$'\e[0;90m'
GRN=$'\e[0;32m'
RED=$'\e[0;31m'
YLW=$'\e[0;33m'
BLD=$'\e[1m'
RST=$'\e[0m'

CHECK_ONLY=0
SKIP=""
ONLY=""
while [[ $# -gt 0 ]]; do
	case "$1" in
	--check) CHECK_ONLY=1 ;;
	--skip)
		shift
		SKIP="$1"
		;;
	--only)
		shift
		ONLY="$1"
		;;
	--help | -h)
		sed -n '2,18p' "$0"
		exit 0
		;;
	*)
		printf '%sunknown arg:%s %s\n' "$RED" "$RST" "$1" >&2
		exit 2
		;;
	esac
	shift
done

p() { printf '%sbootstrap ·%s %s\n' "$DIM" "$RST" "$*"; }
ok() { printf '%sbootstrap ·%s %s%s%s\n' "$GRN" "$RST" "$GRN" "$*" "$RST"; }
warn() { printf '%sbootstrap ·%s %s%s%s\n' "$YLW" "$RST" "$YLW" "$*" "$RST"; }
err() { printf '%sbootstrap ·%s %s%s%s\n' "$RED" "$RST" "$RED" "$*" "$RST" >&2; }

skipped() {
	[[ "$SKIP" == "$1" ]] && return 0
	[[ -n "$ONLY" && "$ONLY" != "$1" ]] && return 0
	return 1
}

FNM_DEFAULT_BIN="$HOME/.local/share/fnm/aliases/default/bin"
CAVEMEM_DIR="$HOME/.local/share/fnm/aliases/default/lib/node_modules/cavemem"
XENOVA_DIR="$HOME/.local/share/fnm/aliases/default/lib/node_modules/@xenova/transformers"
CAVEMEM_HEALTH="${CAVEMEM_HEALTH:-$HOME/.bin/cavemem-health.sh}"
BSQL_PIN="better-sqlite3@12.11.1" # workaround: WiseLibs/better-sqlite3#1515

cavemem_pin_bsql() {
	(
		cd "$CAVEMEM_DIR" || exit 1
		[[ -e .npmrc ]] && {
			err "$CAVEMEM_DIR/.npmrc exists — remove it first"
			exit 1
		}
		trap 'rm -f .npmrc' EXIT INT TERM
		printf 'allow-scripts=better-sqlite3\n' >.npmrc
		npm i --no-save "$BSQL_PIN"
	)
}

json_field() {
	"$FNM_DEFAULT_BIN/node" -e 'try { console.log(JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))[process.argv[2]] ?? "") } catch { console.log("") }' "$1" "$2" 2>/dev/null
}

cavemem_has() {
	grep -q "^$1 " <<<"$2"
}

cavemem_worker_pid() {
	local pid
	pid=$(cat "$HOME/.cavemem/worker.pid" 2>/dev/null) && kill -0 "$pid" 2>/dev/null && printf '%s' "$pid"
}

cavemem_wait_worker() {
	local dim
	for _ in 1 2 3 4 5 6 7 8 9 10; do
		[[ -n "$(cavemem_worker_pid)" ]] || return 0
		dim=$(json_field "$HOME/.cavemem/worker.state.json" dim)
		[[ "$dim" =~ ^[1-9][0-9]*$ ]] && return 0
		sleep 2
	done
}

cavemem_install_xenova() {
	local version
	version=$(json_field "$XENOVA_DIR/package.json" version)
	npm i -g "@xenova/transformers${version:+@$version}" --allow-scripts=sharp,protobufjs || {
		err "npm i -g @xenova/transformers failed"
		return 1
	}
}

cavemem_reinstall() {
	local version
	version=$(json_field "$CAVEMEM_DIR/package.json" version)
	npm i -g --ignore-scripts "cavemem${version:+@$version}" || {
		err "npm i -g cavemem failed"
		return 1
	}
}

cavemem_install() {
	if ! command -v npm >/dev/null 2>&1; then
		err "npm not in PATH — set up fnm default node first ('fnm install --lts && fnm default <ver>')"
		return 1
	fi
	p "installing cavemem + @xenova/transformers via npm…"
	cavemem_reinstall && cavemem_install_xenova || return 1
	cavemem_pin_bsql || {
		err "npm i --no-save $BSQL_PIN failed"
		return 1
	}
}

step_cavemem() {
	local -x PATH="$FNM_DEFAULT_BIN:$PATH"
	local problems msg pid
	if [[ ! -x "$CAVEMEM_HEALTH" ]]; then
		err "$CAVEMEM_HEALTH missing — run 'chezmoi apply ~/.bin'"
		return 1
	fi
	if problems=$("$CAVEMEM_HEALTH"); then
		ok "cavemem $(cavemem --version 2>/dev/null) healthy: hook, better-sqlite3, embedder, worker"
		return 0
	fi
	if ((CHECK_ONLY)); then
		while read -r _ msg; do
			warn "$msg — run '--only cavemem'"
		done <<<"$problems"
		return 1
	fi
	pid=$(cavemem_worker_pid)
	if cavemem_has missing "$problems" || cavemem_has start "$problems"; then
		cavemem_install || return 1
	else
		if cavemem_has bsql "$problems"; then
			p "pinning $BSQL_PIN under cavemem…"
			cavemem_pin_bsql || {
				err "npm i --no-save $BSQL_PIN failed"
				return 1
			}
		fi
		if cavemem_has hook "$("$CAVEMEM_HEALTH")"; then
			p "reinstalling cavemem…"
			cavemem_reinstall || return 1
			cavemem_pin_bsql || {
				err "npm i --no-save $BSQL_PIN failed"
				return 1
			}
		fi
		if cavemem_has embedder "$problems"; then
			p "reinstalling @xenova/transformers with the sharp build…"
			cavemem_install_xenova || return 1
		fi
	fi
	if [[ -n "$pid" ]]; then
		p "restarting the cavemem worker…"
		cavemem restart >/dev/null || warn "cavemem restart failed"
	fi
	cavemem_wait_worker
	if ! problems=$("$CAVEMEM_HEALTH"); then
		while read -r _ msg; do
			err "$msg"
		done <<<"$problems"
		return 1
	fi
	ok "cavemem repaired: hook, better-sqlite3, embedder, worker"
}

step_mcp() {
	if ! command -v chezmoi >/dev/null 2>&1; then
		warn "chezmoi missing — cannot reconcile MCP"
		return 1
	fi
	if ((CHECK_ONLY)); then
		if [[ -z "$(chezmoi diff "$HOME/.claude.json" 2>/dev/null)" ]]; then
			ok "MCP in sync"
			return 0
		fi
		warn "MCP drift — run 'chezmoi apply ~/.claude.json'"
		return 1
	fi
	if chezmoi apply "$HOME/.claude.json" >/dev/null 2>&1; then
		ok "MCP reconciled"
	else
		warn "chezmoi apply failed for ~/.claude.json"
		return 1
	fi
}

step_plugins() {
	if ! command -v jq >/dev/null 2>&1; then
		err "jq required to parse $SETTINGS"
		return 1
	fi
	if [[ ! -r "$SETTINGS" ]]; then
		warn "settings.json missing at $SETTINGS — skipping plugin install"
		return 0
	fi
	local enabled
	enabled=$(jq -r '(.enabledPlugins // {}) | to_entries[] | select(.value == true) | .key' "$SETTINGS" 2>/dev/null)
	if [[ -z "$enabled" ]]; then
		warn "no enabledPlugins entries"
		return 0
	fi
	if ! command -v claude >/dev/null 2>&1; then
		err "claude CLI not in PATH — install Claude Code first"
		return 1
	fi
	local installed
	installed=$(claude plugin list 2>/dev/null || true)

	local needed=0 p_id
	while IFS= read -r p_id; do
		[[ -z "$p_id" ]] && continue
		if printf '%s\n' "$installed" | grep -q "❯ ${p_id}"; then
			ok "plugin '$p_id' present"
			continue
		fi
		needed=$((needed + 1))
		if ((CHECK_ONLY)); then
			warn "plugin '$p_id' missing — run 'claude plugin install $p_id'"
			continue
		fi
		p "installing plugin '$p_id'…"
		claude plugin install "$p_id" || {
			err "claude plugin install $p_id failed"
			return 1
		}
	done <<<"$enabled"
	((needed == 0)) && ok "all plugins enabled"
}

step_verify() {
	local doctor="$HOME/.bin/chezmoi-claude-doctor.sh"
	if [[ ! -x "$doctor" ]]; then
		warn "doctor missing at $doctor — skipping verify"
		return 1
	fi
	p "running doctor (5 phases)…"
	"$doctor" || {
		err "doctor reported drift — review above"
		return 1
	}
	ok "doctor 5/5 clean"
}

main() {
	local mode=install
	((CHECK_ONLY)) && mode=check-only
	printf '\n%sChezmoi Claude bootstrap%s%s — %s\n\n' "$BLD" "$RST" "$DIM" "$mode"
	printf "%s\n\n" "${RST}"

	local rc=0
	for step in cavemem mcp plugins verify; do
		if skipped "$step"; then
			printf '%sbootstrap ·%s skip %s\n' "$DIM" "$RST" "$step"
			continue
		fi
		printf '\n%s── %s%s\n' "$BLD" "$step" "$RST"
		"step_$step" || rc=1
	done

	printf '\n'
	if ((rc == 0)); then
		ok "bootstrap complete"
	else
		err "bootstrap had failures — review above"
	fi
	return "$rc"
}

main
exit $?
