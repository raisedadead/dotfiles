#!/bin/bash
# @name: github-issue
# @description: Fetch GitHub issue metadata and suggest branch name
# @events: pre_create
# @requires: gh

source "$WT_LIB/helpers.sh"
wt_requires gh
wt_requires jq

# Get issue number from environment or prompt
issue_num="${WT_ISSUE:-}"
if [ -z "$issue_num" ]; then
    # Only prompt if stdin is a TTY (interactive mode)
    if [ -t 0 ]; then
        read -p "Issue number: " issue_num
    else
        wt_error "Issue number is required. Use --issue <number> or run interactively."
    fi
fi

if [ -z "$issue_num" ]; then
    wt_error "Issue number is required"
fi

# Fetch issue from GitHub
wt_info "Fetching issue #$issue_num..."
issue=$(gh issue view "$issue_num" --json number,title,labels,url 2>&1)
if [ $? -ne 0 ]; then
    wt_error "Failed to fetch issue #$issue_num: $issue"
fi

number=$(echo "$issue" | jq -r '.number')
title=$(echo "$issue" | jq -r '.title')
url=$(echo "$issue" | jq -r '.url')

# Generate branch name using workflow prefix or default
prefix="${WT_WORKFLOW_PREFIX:-fix}"
slug=$(wt_slugify "$title")
branch_name="${prefix}-${number}-${slug}"

wt_set_branch "$branch_name"
wt_set_meta "issue_number" "$number"
wt_set_meta "issue_title" "$title"
wt_set_meta "issue_url" "$url"

wt_info "Linked to issue #$number: $title"
