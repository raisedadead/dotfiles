#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034

. "$(dirname "$0")/colors.sh"

D="$CLR_DIM"
Y="$CLR_ACCENT"
R="$CLR_RST"

W1=24  # label width

action() {
  local tag="$1" key="$2" label="$3" desc="$4"
  printf "%s\t  ${Y}%s${R}  %-${W1}s ${D}%s${R}\n" "$tag" "$key" "$label" "$desc"
}

commands() {
  action "park"      "1" "Park Session"         "Save and remove session"
  action "unpark"    "2" "Unpark Session"        "Restore a parked session"
  action "sync"      "3" "Sync Panes"            "Toggle input sync"
  action "break-win" "4" "Break Pane to Window"  "Pane → new window"
  action "break-ses" "5" "Break Pane to Session" "Pane → new session"
  action "eq-v"      "6" "Equalize Vertical"     "Stack panes evenly"
  action "eq-h"      "7" "Equalize Horizontal"   "Tile panes evenly"
  action "save"      "8" "Save Sessions"         "Resurrect save all"
  action "restore"   "9" "Restore Sessions"      "Resurrect restore all"
  action "beads"     "0" "Beads"                 "Watch beads in cwd"
  action "url"       " " "URL Picker"            "Open URLs from scrollback"
  action "new-win"   " " "New Window"            "Open in cwd"
  action "last-ses"  " " "Last Session"          "Toggle previous session"
  action "cmd"       " " "Command Prompt"        "tmux command line"
  action "keys"      " " "Keybindings"           "Search all keybinds"
}

BINDS=(
  --bind "1:become(echo park)"
  --bind "2:become(echo unpark)"
  --bind "3:become(echo sync)"
  --bind "4:become(echo break-win)"
  --bind "5:become(echo break-ses)"
  --bind "6:become(echo eq-v)"
  --bind "7:become(echo eq-h)"
  --bind "8:become(echo save)"
  --bind "9:become(echo restore)"
  --bind "0:become(echo beads)"
  --bind "enter:become(echo {1})"
)

selected=$(commands | fzf-tmux -p 24%,28% \
  --no-sort --no-info --ansi --border=rounded --border-label=' Commands ' --padding=1,2 \
  --color="$FZF_MOCHA_COLORS" \
  --no-input \
  --delimiter='\t' --with-nth=2 \
  --footer "$D  Quick Action [Key] ◆ Navigate [j/k] ◆ Quit [Esc]$R" \
  --footer-border=line \
  "${BINDS[@]}" \
  --bind 'esc:abort' --bind 'q:abort')

[ -z "$selected" ] && exit 0

case "$selected" in
  park)
    tmux run-shell "$HOME/.config/tmux/scripts/park-session.sh || true" ;;
  unpark)
    tmux display-popup -E -w 40% -h 40% -b rounded -T '#[align=centre] Unpark Session ' "$HOME/.config/tmux/scripts/unpark-session.sh" ;;
  eq-v)
    tmux select-layout even-vertical ;;
  eq-h)
    tmux select-layout even-horizontal ;;
  sync)
    tmux setw synchronize-panes \; if -F "#{pane_synchronized}" "set pane-active-border-style fg=#F38BA8 ; set pane-border-lines single ; set pane-border-status bottom" "set pane-active-border-style fg=#f5e0dc ; set pane-border-lines single ; set pane-border-status off" ;;
  break-win)
    tmux break-pane ;;
  break-ses)
    tmux command-prompt -p "Break to session:" "run-shell \"$HOME/.config/tmux/scripts/break-pane-to-session.sh '#{pane_id}' '#{pane_current_path}' '%%'\"" ;;
  new-win)
    tmux new-window -c "#{pane_current_path}" ;;
  last-ses)
    tmux switch-client -l ;;
  beads)
    tmux display-popup -E -w 48% -h 54% -b rounded -T '#[align=centre] Beads ' -d "#{pane_current_path}" "$HOME/.config/tmux/scripts/beads-popup.sh" ;;
  url)
    tmux run-shell -b "$HOME/.config/tmux/plugins/tmux-fzf-url/fzf-url.sh '' 2000 'open' ''" ;;
  save)
    tmux run-shell "$HOME/.config/tmux/plugins/tmux-resurrect/scripts/save.sh" ;;
  restore)
    tmux run-shell "$HOME/.config/tmux/plugins/tmux-resurrect/scripts/restore.sh" ;;
  cmd)
    tmux command-prompt ;;
  keys)
    tmux run-shell "$HOME/.config/tmux/scripts/keyb-popup.sh || true" ;;
esac
