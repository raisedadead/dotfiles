#!/bin/sh
# Git prompt for starship - worktree-aware
# Suppresses output in worktree containers (directories with .bare)
# Optimized: POSIX sh, 2 git commands instead of 6

# Skip if in worktree container
[ -d ".bare" ] && exit 0

# Get branch + status in one command
git_status=$(git status --porcelain -b 2>/dev/null) || exit 0
[ -z "$git_status" ] && exit 0

# Parse branch from first line: ## main...origin/main or ## HEAD (detached)
branch=$(echo "$git_status" | head -1 | sed 's/^## //; s/\.\.\..*//; s/ \[.*//; s/No commits yet on //')
[ -z "$branch" ] && exit 0

# Parse status from remaining lines
status=""
status_lines=$(echo "$git_status" | tail -n +2)

# Check patterns using case for speed (no subshell/grep)
case "$status_lines" in
    [MADRC]*) status="${status}+" ;;
esac

# Check for unstaged/untracked/deleted with grep (one call, multiple patterns)
if [ -n "$status_lines" ]; then
    echo "$status_lines" | grep -qE '^.[MDRC]' && status="${status}!"
    echo "$status_lines" | grep -qF '??' && status="${status}?"
    echo "$status_lines" | grep -qE '^D|^.D' && status="${status}✘"
fi

# Stash check via file existence (no git command)
git_dir=$(git rev-parse --git-dir 2>/dev/null)
[ -f "$git_dir/refs/stash" ] && status="${status}\$"

# Output
if [ -n "$status" ]; then
    echo "$branch [$status]"
else
    echo "$branch"
fi
