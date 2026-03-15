#!/bin/sh
# @name: github-pr
# @description: Checkout PR branch for review (uses actual PR head branch)
# @events: pre_create
# @requires: gh

. "$WT_LIB/helpers.sh"
wt_requires gh
wt_requires jq

# Get PR number from environment or prompt
pr_num="${WT_PR:-}"
if [ -z "$pr_num" ]; then
    # Only prompt if stdin is a TTY (interactive mode)
    if [ -t 0 ]; then
        printf "PR number: "
        read pr_num
    else
        wt_error "PR number is required. Use --pr <number> or run interactively."
    fi
fi

if [ -z "$pr_num" ]; then
    wt_error "PR number is required"
fi

# Fetch PR from GitHub
wt_info "Fetching PR #$pr_num..."
if ! pr=$(gh pr view "$pr_num" --json number,title,author,headRefName,url,state 2>&1); then
    wt_error "Failed to fetch PR #$pr_num: $pr"
fi

number=$(echo "$pr" | jq -r '.number')
title=$(echo "$pr" | jq -r '.title')
author=$(echo "$pr" | jq -r '.author.login')
branch=$(echo "$pr" | jq -r '.headRefName')
url=$(echo "$pr" | jq -r '.url')
state=$(echo "$pr" | jq -r '.state')

# Use the actual PR head branch so gh pr browse works
wt_set_branch "$branch"
wt_set_meta "pr_number" "$number"
wt_set_meta "pr_title" "$title"
wt_set_meta "pr_author" "$author"
wt_set_meta "pr_url" "$url"
wt_set_meta "pr_state" "$state"
wt_set_meta "track_remote" "true"

wt_info "PR #$number by @$author: $title"
wt_info "Branch: $branch (state: $state)"
