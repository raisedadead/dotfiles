#!/usr/bin/env bash
# chezmoi-claude-bootstrap — fresh-machine setup for the Claude Code rig.
#
# Idempotent. Run after `chezmoi init --apply` (clone + apply). Installs what
# chezmoi cannot: the cavemem package, the MCP merge, and the plugins.
#
# Steps (each idempotent — re-runs are safe):
#   1. cavemem  — npm i -g cavemem on fnm-default node
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

step_cavemem() {
	local bin xenova="$HOME/.local/share/fnm/aliases/default/lib/node_modules/@xenova/transformers"
	bin=$(command -v cavemem 2>/dev/null)
	if [[ -n "$bin" ]] && cavemem --version >/dev/null 2>&1 && [[ -d "$xenova" ]]; then
		ok "cavemem present ($($bin --version 2>/dev/null | head -1)) + @xenova embedder"
		return 0
	fi
	if ((CHECK_ONLY)); then
		[[ -z "$bin" ]] && warn "cavemem missing — run 'npm i -g cavemem @xenova/transformers --allow-scripts=sharp,protobufjs'"
		[[ -n "$bin" && ! -d "$xenova" ]] && warn "@xenova/transformers missing (undeclared cavemem dep) — run 'npm i -g @xenova/transformers --allow-scripts=sharp,protobufjs'"
		return 1
	fi
	if ! command -v npm >/dev/null 2>&1; then
		err "npm not in PATH — set up fnm default node first ('fnm install --lts && fnm default <ver>')"
		return 1
	fi
	p "installing cavemem + @xenova/transformers via npm…"
	npm i -g cavemem @xenova/transformers --allow-scripts=sharp,protobufjs || {
		err "npm i -g cavemem @xenova/transformers failed"
		return 1
	}
	ok "cavemem + @xenova embedder installed"
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
	printf '\n%sChezmoi Claude bootstrap%s%s — %s\n\n' "$BLD" "$RST" "$DIM" "${CHECK_ONLY:+check-only}"
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
