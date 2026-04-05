#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034

SELF="$0"
. "$(dirname "$0")/colors.sh"

CACHE="/tmp/keyb-popup-cache"
STATE="/tmp/keyb-popup-state"

CATS=(all tmux ghostty yazi fzf atuin zsh)

# Nerd Font icons via escape sequences
_ico_all=$'\U000F0AB6'       # nf-md-format_list_bulleted_square
_ico_tmux=$'\U000F018D'      # nf-md-console
_ico_ghostty=$'\U000F0322'   # nf-md-ghost
_ico_yazi=$'\U000F024B'      # nf-md-folder
_ico_fzf=$'\U000F0349'       # nf-md-magnify
_ico_atuin=$'\U000F02DA'     # nf-md-history
_ico_zsh=$'\U000F018D'       # nf-md-console (same as tmux)
CAT_ICONS=("$_ico_all" "$_ico_tmux" "$_ico_ghostty" "$_ico_yazi" "$_ico_fzf" "$_ico_atuin" "$_ico_zsh")

D="$CLR_DIM"
M="$CLR_ACCENT"
R="$CLR_RST"

make_header() {
  local active="$1" first=1 i=0
  for cat in "${CATS[@]}"; do
    [ "$first" = "1" ] && first=0 || printf ' %s◆%s ' "$CLR_DIM" "$R"
    if [ "$cat" = "$active" ]; then
      printf '%s%s%s%s' "$M" "${CAT_ICONS[$i]}" "$cat" "$R"
    else
      printf '%s%s%s%s' "$CLR_SUB" "${CAT_ICONS[$i]}" "$cat" "$R"
    fi
    (( i++ ))
  done
  printf ''
}

keyb_content() {
  local cat="$1"
  if [ "$cat" = "all" ]; then
    awk -v d="$CLR_DIM" -v r="$CLR_RST" '
      /^(tmux|ghostty|yazi|fzf|atuin|zsh)/ { printf "%s%s%s\n", d, $0, r; next }
      /^[[:space:]]*$/ { next }
      { print }
    ' "$CACHE"
  else
    awk -v cat="$cat" -v d="$CLR_DIM" -v r="$CLR_RST" '
      $0 ~ "^"cat { f=1; printf "%s%s%s\n", d, $0, r; next }
      /^(tmux|ghostty|yazi|fzf|atuin|zsh)/ { f=0 }
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

keyb_content "all" | fzf --tmux center,37%,60% \
  --no-sort --no-info --ansi \
  --border=rounded --border-label=' Keybindings ' --padding=1,2 \
  --header-first --header-border=line \
  --header "$header" \
  --color="$FZF_MOCHA_COLORS" \
  --prompt "Keybindings ❯ " \
  --footer "${CLR_DIM}  Category [Tab] ◆ Quit [Q]${CLR_RST}" \
  --footer-border=line \
  --bind 'enter:ignore' \
  --bind 'esc:abort' --bind 'q:abort' \
  --bind "btab:transform($SELF --cycle prev)" \
  --bind "tab:transform($SELF --cycle next)"
