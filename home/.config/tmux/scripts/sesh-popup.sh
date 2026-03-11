#!/usr/bin/env bash

D=$'\033[90m'  # dim (brightblack)
M=$'\033[93m'  # bright yellow
R=$'\033[0m'   # reset

H_ALL="${M}all${R}${D} (^a) • tmux (^t) • configs (^g) • zoxide (^x) • kill (^d) • find (^f)${R}"
H_TMUX="${D}all (^a) • ${M}tmux${R}${D} (^t) • configs (^g) • zoxide (^x) • kill (^d) • find (^f)${R}"
H_CONFIGS="${D}all (^a) • tmux (^t) • ${M}configs${R}${D} (^g) • zoxide (^x) • kill (^d) • find (^f)${R}"
H_ZOXIDE="${D}all (^a) • tmux (^t) • configs (^g) • ${M}zoxide${R}${D} (^x) • kill (^d) • find (^f)${R}"
H_FIND="${D}all (^a) • tmux (^t) • configs (^g) • zoxide (^x) • kill (^d) • ${M}find${R}${D} (^f)${R}"

selected=$(sesh list --icons | fzf-tmux -p 53%,60% \
  --no-sort --no-info --ansi --border=rounded --border-label=' Sessions ' --padding=1,2 \
  --header-first --header-border=line \
  --header "$H_ALL" \
  --color='header:8,pointer:yellow,prompt:yellow,border:white,label:yellow' \
  --prompt '  ' \
  --preview 'sesh preview {}' --preview-window 'right:50%,hidden' \
  --bind 'tab:down,btab:up' \
  --bind 'esc:abort' \
  --bind "ctrl-a:change-prompt(  )+reload(sesh list --icons)+hide-preview+change-header($H_ALL)" \
  --bind "ctrl-t:change-prompt(  )+reload(sesh list -t --icons)+show-preview+change-header($H_TMUX)" \
  --bind "ctrl-g:change-prompt(  )+reload(sesh list -c --icons)+hide-preview+change-header($H_CONFIGS)" \
  --bind "ctrl-x:change-prompt(  )+reload(sesh list -z --icons)+hide-preview+change-header($H_ZOXIDE)" \
  --bind "ctrl-f:change-prompt(  )+reload(fd -H -d 2 -t d -E .Trash . ~)+hide-preview+change-header($H_FIND)" \
  --bind "ctrl-d:execute(tmux kill-session -t {2..})+change-prompt(  )+reload(sesh list --icons)+change-header($H_ALL)")

[ -n "$selected" ] && sesh connect "$selected"
