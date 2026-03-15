#!/usr/bin/env bash

SELF="$0"
CACHE="/tmp/keyb-popup-cache"
STATE="/tmp/keyb-popup-state"

CATS=(all tmux ghostty yazi fzf atuin zsh sesh)

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
  printf '  %stab ⇥%s' "$D" "$R"
}

keyb_content() {
  local cat="$1"
  if [ "$cat" = "all" ]; then
    awk -v d="\033[90m" -v r="\033[0m" '
      /^(tmux|ghostty|sesh|yazi|fzf|atuin|zsh)/ { printf "%s%s%s\n", d, $0, r; next }
      /^[[:space:]]*$/ { next }
      { print }
    ' "$CACHE"
  else
    awk -v cat="$cat" -v d="\033[90m" -v r="\033[0m" '
      $0 ~ "^"cat { f=1; printf "%s%s%s\n", d, $0, r; next }
      /^(tmux|ghostty|sesh|yazi|fzf|atuin|zsh)/ { f=0 }
      f && /^[[:space:]]*$/ { next }
      f
    ' "$CACHE"
  fi
}

case "${1:-}" in
  --show)
    keyb_content "$2"
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
    header=$(make_header "${CATS[$idx]}")
    printf '%s' "reload($SELF --show ${CATS[$idx]})+change-header($header)"
    exit ;;
esac

# Main entry
keyb -p > "$CACHE"
echo "0" > "$STATE"
trap 'rm -f "$CACHE" "$STATE"' EXIT

header=$(make_header "all")

keyb_content "all" | fzf-tmux -p 53%,60% \
  --no-sort --no-info --ansi --border=rounded --border-label=' Keybindings ' --padding=1,2 \
  --header-first --header-border=line \
  --header "$header" \
  --color='header:8,pointer:yellow,prompt:yellow,border:white,label:yellow' \
  --prompt '  ' \
  --bind 'esc:abort' \
  --bind "btab:transform($SELF --cycle prev)" \
  --bind "tab:transform($SELF --cycle next)"
