#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034

. "$(dirname "$0")/colors.sh"

D="$CLR_DIM"
Y="$CLR_ACCENT"
R="$CLR_RST"

_ico_cmd=$'\uEA8E'  # nf-cod-run_all

W1=22  # label width

# Quick actions: shortcut key shown prominently on each line
action() {
  local key="$1" label="$2" desc="$3"
  printf "  ${Y}%s${R}  %-${W1}s ${D}%s${R}\n" "$key" "$label" "$desc"
}

commands() {
  action "1" "Equalize Vertical" "Stack panes evenly"
  action "2" "Equalize Horizontal" "Tile panes evenly"
  action "3" "Sync Panes" "Toggle input sync"
  action "4" "Break Pane to Window" "Pane → new window"
  action "5" "Break Pane to Session" "Pane → new session"
  action "6" "New Window" "Open in cwd"
  action "7" "Last Session" "Toggle previous session"
  action "8" "URL Picker" "Open URLs from scrollback"
  action "9" "Command Prompt" "tmux command line"
  action "0" "Keybindings" "Search all keybinds"
}

# Quick shortcuts: single key fires immediately (search disabled)
BINDS=(
  --bind "1:become(echo __EQUALIZE_V__)"
  --bind "2:become(echo __EQUALIZE_H__)"
  --bind "3:become(echo __SYNC_PANES__)"
  --bind "4:become(echo __BREAK_WINDOW__)"
  --bind "5:become(echo __BREAK_SESSION__)"
  --bind "6:become(echo __NEW_WINDOW__)"
  --bind "7:become(echo __LAST_SESSION__)"
  --bind "8:become(echo __URL_PICKER__)"
  --bind "9:become(echo __CMD_PROMPT__)"
  --bind "0:become(echo __KEYBINDINGS__)"
)

selected=$(commands | fzf-tmux -p 24%,22% \
  --no-sort --no-info --ansi --disabled --border=rounded --border-label=' Commands ' --padding=1,2 \
  --color="$FZF_MOCHA_COLORS" \
  --no-input \
  --footer "$D  Quick Action [Key] ◆ Quit [Esc]$R" \
  --footer-border=line \
  "${BINDS[@]}" \
  --bind 'esc:abort' --bind 'q:abort')

[ -z "$selected" ] && exit 0

# Quick shortcut dispatch
case "$selected" in
  __EQUALIZE_V__)
    tmux select-layout even-vertical; exit 0 ;;
  __EQUALIZE_H__)
    tmux select-layout even-horizontal; exit 0 ;;
  __SYNC_PANES__)
    tmux setw synchronize-panes \; if -F "#{pane_synchronized}" "set pane-active-border-style fg=#F38BA8 ; set pane-border-status bottom" "set pane-active-border-style fg=white ; set pane-border-status off"; exit 0 ;;
  __BREAK_WINDOW__)
    tmux break-pane; exit 0 ;;
  __BREAK_SESSION__)
    tmux command-prompt -p "Break to session:" "run-shell \"$HOME/.config/tmux/scripts/break-pane-to-session.sh '#{pane_id}' '#{pane_current_path}' '%%'\""; exit 0 ;;
  __NEW_WINDOW__)
    tmux new-window -c "#{pane_current_path}"; exit 0 ;;
  __LAST_SESSION__)
    tmux switch-client -l; exit 0 ;;
  __URL_PICKER__)
    tmux run-shell -b "$HOME/.config/tmux/plugins/tmux-fzf-url/fzf-url.sh '' 2000 'open' ''"; exit 0 ;;
  __CMD_PROMPT__)
    tmux command-prompt; exit 0 ;;
  __KEYBINDINGS__)
    tmux run-shell "$HOME/.config/tmux/scripts/keyb-popup.sh || true"; exit 0 ;;
esac
