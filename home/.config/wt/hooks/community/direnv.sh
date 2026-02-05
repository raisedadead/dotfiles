#!/bin/bash
# @name: direnv
# @description: Auto-allow .envrc files in worktrees
# @events: post_add
# @requires: direnv

cd "$WT_PATH" || exit 0

# Skip if direnv not installed
command -v direnv &>/dev/null || exit 0

# Skip if no .envrc
[[ -f .envrc ]] || exit 0

direnv allow
