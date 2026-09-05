#!/usr/bin/env bash
# chezmoi-claude-hooks-test — run the hooks dispatcher test suite.
#
# Thin wrapper around the test files under
# ~/.dotfiles/dot_claude/hooks/. They are chezmoiignored from deploy,
# so they only exist in the source tree.
#
# Default: `python3 test_hooks.py` (1125+ LOC behavioral suite).
# `--pytest` runs `pytest test_executable_hooks.py` (contract tests) instead.
# `--all` runs both.
#
# Usage:
#   chezmoi-claude-hooks-test.sh           # behavioral suite only
#   chezmoi-claude-hooks-test.sh --pytest  # contract suite only
#   chezmoi-claude-hooks-test.sh --all     # both
#   chezmoi-claude-hooks-test.sh --quiet   # pipe output through rtk err for compression

set -uo pipefail

PRIV_SOURCE="${PRIV_SOURCE:-$HOME/.dotfiles}"
HOOK_DIR="$PRIV_SOURCE/dot_claude/hooks"

MODE="behavioral"
QUIET=0
while [[ $# -gt 0 ]]; do
	case "$1" in
	--pytest) MODE="contract" ;;
	--all) MODE="all" ;;
	--quiet) QUIET=1 ;;
	--help | -h)
		sed -n '2,16p' "$0"
		exit 0
		;;
	*)
		printf 'unknown arg: %s\n' "$1" >&2
		exit 2
		;;
	esac
	shift
done

if [[ ! -d "$HOOK_DIR" ]]; then
	printf 'hook source dir missing: %s\n' "$HOOK_DIR" >&2
	exit 2
fi

run() {
	if ((QUIET)) && command -v rtk >/dev/null 2>&1; then
		rtk err "$@"
	else
		"$@"
	fi
}

cd "$HOOK_DIR" || exit 2

if ! compgen -G 'test_*.py' >/dev/null; then
	printf 'no test_*.py in %s: is the dot_claude submodule initialised?\n' "$HOOK_DIR" >&2
	exit 2
fi

rc=0

if [[ "$MODE" == "behavioral" || "$MODE" == "all" ]]; then
	printf '── test_hooks.py (behavioral)\n'
	run python3 test_hooks.py || rc=$?
fi

if [[ "$MODE" == "contract" || "$MODE" == "all" ]]; then
	printf '── test_executable_hooks.py (contract)\n'
	if command -v pytest >/dev/null 2>&1; then
		run pytest test_executable_hooks.py || rc=$?
	elif python3 -c 'import pytest' >/dev/null 2>&1; then
		run python3 -m pytest test_executable_hooks.py || rc=$?
	else
		run python3 test_executable_hooks.py || rc=$?
	fi
fi

exit "$rc"
