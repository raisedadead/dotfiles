#!/bin/bash
# @name: gh-default
# @description: Auto-configure GitHub CLI default repository
# @events: post_clone
# @requires: gh

# Source helpers if available
if [[ -n "$WT_LIB" && -f "$WT_LIB/helpers.sh" ]]; then
    source "$WT_LIB/helpers.sh"
else
    # Fallback definitions if helpers not available
    wt_warn() { echo "warning: $1" >&2; }
    wt_info() { echo "$1"; }
fi

cd "$WT_PATH" || exit 0

# Skip if gh not installed
if ! command -v gh &>/dev/null; then
    wt_warn "gh CLI not installed, skipping repo default setup"
    exit 0
fi

# Skip if already configured
if gh repo set-default --view &>/dev/null; then
    exit 0
fi

# Get remotes
origin=$(git remote get-url origin 2>/dev/null)
upstream=$(git remote get-url upstream 2>/dev/null)

# Detection logic:
# 1. origin + upstream exist → use upstream (fork pattern)
# 2. only origin exists → use origin
# 3. other patterns → skip silently

if [[ -n "$upstream" && -n "$origin" ]]; then
    if gh repo set-default "$upstream" 2>/dev/null; then
        wt_info "Set gh default to upstream: $upstream"
    fi
elif [[ -n "$origin" && -z "$upstream" ]]; then
    if gh repo set-default "$origin" 2>/dev/null; then
        wt_info "Set gh default to origin: $origin"
    fi
fi
