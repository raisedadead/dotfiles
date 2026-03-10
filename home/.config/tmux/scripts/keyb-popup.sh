#!/usr/bin/env bash

keyb_all() {
  keyb -p | awk \
    -v r="\033[0m" \
    -v tmux="\033[35m" \
    -v ghostty="\033[34m" \
    -v sesh="\033[32m" \
    -v yazi="\033[33m" \
    -v zsh="\033[36m" '
    /^tmux/    { cat="tmux";    c=tmux;    next }
    /^ghostty/ { cat="ghostty"; c=ghostty; next }
    /^sesh/    { cat="sesh";    c=sesh;    next }
    /^yazi/    { cat="yazi";    c=yazi;    next }
    /^zsh/     { cat="zsh";     c=zsh;     next }
    /^[[:space:]]*$/ { next }
    { printf "%s  %s%s%s\n", $0, c, cat, r }
  '
}

keyb_cat() {
  keyb -p | awk -v cat="$1" '
    $0 ~ "^"cat { f=1; next }
    /^(tmux|ghostty|sesh|yazi|zsh)/ { f=0 }
    f && /^[[:space:]]*$/ { next }
    f
  '
}

# Handle reload calls from fzf bindings
case "${1:-}" in
  --all) keyb_all; exit ;;
  --cat) keyb_cat "$2"; exit ;;
esac

# Header fragments — active category gets bright color, others stay dim
D=$'\033[90m'  # dim (brightblack)
M=$'\033[95m'  # bright magenta
R=$'\033[0m'   # reset
H_ALL="${M}all${R}${D} (^a) • tmux (^t) • ghostty (^g) • yazi (^y) • zsh (^z) • sesh (^s)${R}"
H_TMUX="${D}all (^a) • ${M}tmux${R}${D} (^t) • ghostty (^g) • yazi (^y) • zsh (^z) • sesh (^s)${R}"
H_GHOSTTY="${D}all (^a) • tmux (^t) • ${M}ghostty${R}${D} (^g) • yazi (^y) • zsh (^z) • sesh (^s)${R}"
H_YAZI="${D}all (^a) • tmux (^t) • ghostty (^g) • ${M}yazi${R}${D} (^y) • zsh (^z) • sesh (^s)${R}"
H_ZSH="${D}all (^a) • tmux (^t) • ghostty (^g) • yazi (^y) • ${M}zsh${R}${D} (^z) • sesh (^s)${R}"
H_SESH="${D}all (^a) • tmux (^t) • ghostty (^g) • yazi (^y) • zsh (^z) • ${M}sesh${R}${D} (^s)${R}"

keyb_all | fzf-tmux -p 53%,60% \
  --no-sort --no-info --ansi --border=rounded --padding=0,1 \
  --header-first --header-border=line \
  --header "$H_ALL" \
  --color='header:8,pointer:magenta,prompt:magenta,border:white' \
  --prompt '  ' \
  --bind 'esc:abort' \
  --bind "ctrl-a:reload($0 --all)+change-header($H_ALL)" \
  --bind "ctrl-t:reload($0 --cat tmux)+change-header($H_TMUX)" \
  --bind "ctrl-g:reload($0 --cat ghostty)+change-header($H_GHOSTTY)" \
  --bind "ctrl-y:reload($0 --cat yazi)+change-header($H_YAZI)" \
  --bind "ctrl-z:reload($0 --cat zsh)+change-header($H_ZSH)" \
  --bind "ctrl-s:reload($0 --cat sesh)+change-header($H_SESH)"
