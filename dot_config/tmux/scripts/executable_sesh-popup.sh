#!/usr/bin/env bash

SELF="$0"
STATE="/tmp/sesh-popup-state"

CATS=(all tmux configs zoxide find)

D=$'\033[90m'
M=$'\033[93m'
R=$'\033[0m'

make_header() {
  local active="$1" first=1
  printf '  '
  for cat in "${CATS[@]}"; do
    [ "$first" = "1" ] && first=0 || printf ' %s•%s ' "$D" "$R"
    if [ "$cat" = "$active" ]; then
      printf '%s%s%s' "$M" "$cat" "$R"
    else
      printf '%s%s%s' "$D" "$cat" "$R"
    fi
  done
  printf '  %stab ⇥  ^d kill%s' "$D" "$R"
}

sesh_list() {
  case "$1" in
    all)     sesh list --icons ;;
    tmux)    sesh list -t --icons ;;
    configs) sesh list -c --icons ;;
    zoxide)  sesh list -z --icons ;;
    find)    fd -H -d 2 -t d -E .Trash . ~ ;;
  esac
}

case "${1:-}" in
  --show)
    sesh_list "$2"
    exit ;;
  --cycle)
    idx=$(cat "$STATE" 2>/dev/null || echo 0)
    total=${#CATS[@]}
    if [ "$2" = "next" ]; then
      idx=$(( (idx + 1) % total ))
    else
      idx=$(( (idx - 1 + total) % total ))
    fi
    echo "$idx" > "$STATE"
    cat="${CATS[$idx]}"
    header=$(make_header "$cat")
    preview="hide"
    [ "$cat" = "tmux" ] && preview="show"
    printf '%s' "reload($SELF --show $cat)+change-header($header)+${preview}-preview"
    exit ;;
  --reset)
    echo "0" > "$STATE"
    header=$(make_header "all")
    printf '%s' "reload($SELF --show all)+change-header($header)+hide-preview"
    exit ;;
esac

# Main entry
echo "0" > "$STATE"
trap 'rm -f "$STATE"' EXIT

header=$(make_header "all")

selected=$(sesh list --icons | fzf-tmux -p 53%,60% \
  --no-sort --no-info --ansi --border=rounded --border-label=' Sessions ' --padding=1,2 \
  --header-first --header-border=line \
  --header "$header" \
  --color='header:8,pointer:yellow,prompt:yellow,border:white,label:yellow' \
  --prompt '  ' \
  --preview 'sesh preview {}' --preview-window 'right:50%,hidden' \
  --bind 'esc:abort' \
  --bind "btab:transform($SELF --cycle prev)" \
  --bind "tab:transform($SELF --cycle next)" \
  --bind "ctrl-d:execute(tmux kill-session -t {2..})+transform($SELF --reset)")

[ -n "$selected" ] && sesh connect "$selected"
