#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034
set -u

MDR="$HOME/.bin/mdr"
# shellcheck source=colors.sh
. "$(dirname "$0")/colors.sh"

DIM="$CLR_DIM"
ACCENT="$CLR_ACCENT"
SUB="$CLR_SUB"
RST="$CLR_RST"

_ico_all=$'\U000F0E9B'
_ico_doc=$'\U000F0284'
_ico_scratch=$'\U000F0493'
_ico_file=$'\U000F0219'

make_header() {
  local active="$1"
  local -a items=("All" "Docs" "Scratch" "Files")
  local -a keys=("Ctrl+A" "Ctrl+D" "Ctrl+S" "Ctrl+F")
  local result="  " first=1 i
  for i in "${!items[@]}"; do
    [[ "$first" == "1" ]] && first=0 || result+=" ${DIM}·${RST} "
    if [[ "${items[$i]}" == "$active" ]]; then
      result+="${ACCENT}${keys[$i]} ${items[$i]}${RST}"
    else
      result+="${SUB}${keys[$i]} ${items[$i]}${RST}"
    fi
  done
  printf '%s' "$result"
}

HDR_ALL="$(make_header All)"
HDR_DOCS="$(make_header Docs)"
HDR_SCRATCH="$(make_header Scratch)"
HDR_FILES="$(make_header Files)"
FOOTER="${DIM}  Read [⏎] ◆ Preview [Ctrl+/]${RST}"

BIND_ALL="reload($MDR --source all)+change-prompt($_ico_all  All ❯ )+change-header($HDR_ALL)"
BIND_DOCS="reload($MDR --source docs)+change-prompt($_ico_doc  Docs ❯ )+change-header($HDR_DOCS)"
BIND_SCRATCH="reload($MDR --source scratch)+change-prompt($_ico_scratch  Scratch ❯ )+change-header($HDR_SCRATCH)"
BIND_FILES="reload($MDR --source files)+change-prompt($_ico_file  Files ❯ )+change-header($HDR_FILES)"

sel_file="$(mktemp "${TMPDIR:-/tmp}/reader.XXXXXX")" || exit 1
trap 'rm -f "$sel_file"' EXIT

"$MDR" --source all | fzf --tmux center,80%,80% \
  --read0 --print0 --ansi --keep-right --info=right --cycle \
  --delimiter=$'\t' --with-nth 1 \
  --border rounded --border-label ' Reader ' --border-label-pos 3 --padding=1,2 \
  --pointer='▶' --marker='●' --separator='─' --scrollbar='│' \
  --color "$FZF_MOCHA_COLORS" \
  --header "$HDR_ALL" --header-first --header-border=line \
  --prompt "$_ico_all  All ❯ " \
  --footer "$FOOTER" --footer-border=line \
  --preview "$MDR --preview {}" \
  --preview-window 'right:60%' \
  --bind "ctrl-a:$BIND_ALL" \
  --bind "ctrl-d:$BIND_DOCS" \
  --bind "ctrl-s:$BIND_SCRATCH" \
  --bind "ctrl-f:$BIND_FILES" \
  --bind 'ctrl-/:toggle-preview' \
  --bind 'ctrl-o:toggle-preview' \
  --bind 'shift-up:preview-half-page-up' \
  --bind 'shift-down:preview-half-page-down' \
  --bind 'esc:abort' > "$sel_file"

sel=""
IFS= read -r -d '' sel < "$sel_file" || true
rm -f "$sel_file"

file="${sel#*$'\t'}"
[[ -n "$file" && -f "$file" ]] || exit 0

tmux display-popup -EE -w 80% -h 80% -b rounded -d "$PWD" \
  -T '#[align=centre] Reader ' \
  "$(printf '%q --open %q' "$MDR" "$file")"
