#!/bin/bash
# @name: zoxide
# @description: Add worktree to zoxide for quick navigation
# @events: post_clone, post_add
# @requires: zoxide

# Skip if zoxide not installed
command -v zoxide >/dev/null 2>&1 || exit 0

zoxide add "$WT_PATH"
