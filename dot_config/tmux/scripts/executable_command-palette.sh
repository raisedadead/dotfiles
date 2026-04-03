#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034

. "$(dirname "$0")/colors.sh"

D="$CLR_DIM"
Y="$CLR_ACCENT"
R="$CLR_RST"

_ico_cmd=$'\uEA8E'  # nf-cod-run_all

W1=22  # label width
W2=16  # hint width

section() {
  printf "  ${D}── %s ──${R}\n" "$1"
}

entry() {
  local label="$1" hint="$2" desc="$3"
  printf "  %-${W1}s ${D}%-${W2}s %s${R}\n" "$label" "$hint" "$desc"
}

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

  section "Quick Actions"
  action "o" "Switcher" "Switch or create session"
  action "g" "Lazygit" "Git TUI popup"
  action "d" "Split Right" "Pane to the right"
  action "D" "Split Down" "Pane below"
  action "f" "Zoom Toggle" "Toggle fullscreen"
  action "w" "Choose Tree" "Browse sessions/windows"
  action "n" "New Session" "Named session prompt"
  action "k" "Keybindings" "Search all keybinds"
  action "r" "Reload Config" "Re-source tmux.conf"

  section "Other"
  entry "Kill Pane" "pfx+x" "Close active pane"
  entry "Kill Window" "" "Close with confirm"
  entry "Rename Window" "M-R" "Set window title"
  entry "Rename Session" "M-r" "Set session title"
  entry "Kill Session" "" "Destroy with confirm"
  entry "Enter Copy Mode" "pfx+[" "Vi-style selection"
  entry "Paste Buffer" "pfx+]" "Paste last copied text"
  entry "Yank Command Line" "pfx+y" "Copy cmdline to clipboard"
  entry "Yank Pane CWD" "pfx+Y" "Copy cwd to clipboard"
  entry "Display Pane Numbers" "pfx+q" "Show pane indices"
  entry "Detach" "pfx+d" "Detach from session"
}

tmux_commands() {
  section "tmux commands"
  tmux lscm -F '#{command_list_name}#{?command_list_alias, (#{command_list_alias}),}' \
    | while IFS= read -r cmd; do
        printf "  ${D}%s${R}\n" "$cmd"
      done
}

# Quick shortcuts: single key when query is empty, normal typing otherwise
# transform checks {q} (auto-quoted by fzf) and dispatches accordingly
BINDS=(
  --bind "o:transform:[ -z {q} ] && echo 'become(echo __SESH__)' || echo 'put(o)'"
  --bind "g:transform:[ -z {q} ] && echo 'become(echo __LAZYGIT__)' || echo 'put(g)'"
  --bind "d:transform:[ -z {q} ] && echo 'become(echo __SPLIT_H__)' || echo 'put(d)'"
  --bind "D:transform:[ -z {q} ] && echo 'become(echo __SPLIT_V__)' || echo 'put(D)'"
  --bind "f:transform:[ -z {q} ] && echo 'become(echo __ZOOM__)' || echo 'put(f)'"
  --bind "w:transform:[ -z {q} ] && echo 'become(echo __TREE__)' || echo 'put(w)'"
  --bind "n:transform:[ -z {q} ] && echo 'become(echo __NEW_SESSION__)' || echo 'put(n)'"
  --bind "r:transform:[ -z {q} ] && echo 'become(echo __RELOAD__)' || echo 'put(r)'"
  --bind "k:transform:[ -z {q} ] && echo 'become(echo __KEYBINDINGS__)' || echo 'put(k)'"
  --bind "1:transform:[ -z {q} ] && echo 'become(echo __EQUALIZE_V__)' || echo 'put(1)'"
  --bind "2:transform:[ -z {q} ] && echo 'become(echo __EQUALIZE_H__)' || echo 'put(2)'"
  --bind "3:transform:[ -z {q} ] && echo 'become(echo __SYNC_PANES__)' || echo 'put(3)'"
  --bind "4:transform:[ -z {q} ] && echo 'become(echo __BREAK_WINDOW__)' || echo 'put(4)'"
  --bind "5:transform:[ -z {q} ] && echo 'become(echo __BREAK_SESSION__)' || echo 'put(5)'"
  --bind "6:transform:[ -z {q} ] && echo 'become(echo __NEW_WINDOW__)' || echo 'put(6)'"
  --bind "7:transform:[ -z {q} ] && echo 'become(echo __LAST_SESSION__)' || echo 'put(7)'"
  --bind "8:transform:[ -z {q} ] && echo 'become(echo __URL_PICKER__)' || echo 'put(8)'"
  --bind "9:transform:[ -z {q} ] && echo 'become(echo __CMD_PROMPT__)' || echo 'put(9)'"
)

selected=$({ commands; tmux_commands; } | fzf-tmux -p 40%,45% \
  --no-sort --no-info --ansi --border=rounded --border-label=' Commands ' --padding=1,2 \
  --color="$FZF_MOCHA_COLORS" \
  --prompt "Commands ❯ " \
  --footer "$D  Quick Action [Key] ◆ Search [Type]$R" \
  --footer-border=line \
  "${BINDS[@]}" \
  --bind 'esc:abort')

[ -z "$selected" ] && exit 0

# Quick shortcut dispatch
case "$selected" in
  __SESH__)
    tmux run-shell "$HOME/.config/tmux/scripts/switcher.sh || true"; exit 0 ;;
  __LAZYGIT__)
    tmux display-popup -E -w 70% -h 80% -b rounded -T '#[align=centre] Lazygit ' -d "#{pane_current_path}" lazygit; exit 0 ;;
  __SPLIT_H__)
    tmux split-window -h -c "#{pane_current_path}"; exit 0 ;;
  __SPLIT_V__)
    tmux split-window -v -c "#{pane_current_path}"; exit 0 ;;
  __ZOOM__)
    tmux resize-pane -Z; exit 0 ;;
  __TREE__)
    tmux choose-tree -Zw -F "#{?pane_format,#{pane_current_command} #{pane_current_path},#{?window_format,#{window_name} (#{window_panes} panes),#{session_name} (#{session_windows} win)}}"; exit 0 ;;
  __NEW_SESSION__)
    tmux display-popup -E -w 20% -h 5 -b rounded -T '#[align=centre] New Session ' "$HOME/.config/tmux/scripts/new-session-popup.sh"; exit 0 ;;
  __RELOAD__)
    tmux source-file "$HOME/.config/tmux/tmux.conf" \; display-message "Tmux config reloaded"; exit 0 ;;
  __KEYBINDINGS__)
    tmux run-shell "$HOME/.config/tmux/scripts/keyb-popup.sh || true"; exit 0 ;;
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
esac

# Normal selection dispatch
# Strip ANSI, leading whitespace, then skip the 1-char shortcut key if present
label=$(sed -e 's/\x1b\[[0-9;]*m//g' \
            -e 's/^[[:space:]]*//' \
            -e 's/^[[:alnum:]]\{1\}[[:space:]]\{2,\}//' \
            -e 's/[[:space:]]*$//' \
            -e 's/[[:space:]]\{2,\}.*//' <<< "$selected")

case "$label" in
  "──"*) ;;
  "Split Right"|"Split Horizontal")
    tmux split-window -h -c "#{pane_current_path}" ;;
  "Split Down"|"Split Vertical")
    tmux split-window -v -c "#{pane_current_path}" ;;
  "Zoom Toggle"|"Zoom Pane")
    tmux resize-pane -Z ;;
  "Equalize Vertical")
    tmux select-layout even-vertical ;;
  "Equalize Horizontal")
    tmux select-layout even-horizontal ;;
  "Kill Pane")
    tmux kill-pane ;;
  "Sync Panes")
    tmux setw synchronize-panes \; if -F "#{pane_synchronized}" "set pane-active-border-style fg=#F38BA8 ; set pane-border-status bottom" "set pane-active-border-style fg=white ; set pane-border-status off" ;;
  "New Window")
    tmux new-window -c "#{pane_current_path}" ;;
  "Rename Window")
    tmux command-prompt -I "#W" "rename-window -- '%%'" ;;
  "Kill Window")
    tmux confirm-before -p "kill-window #W? (y/n)" kill-window ;;
  "New Session")
    tmux display-popup -E -w 20% -h 5 -b rounded -T '#[align=centre] New Session ' "$HOME/.config/tmux/scripts/new-session-popup.sh" ;;
  "Rename Session")
    tmux command-prompt -I "#S" "rename-session -- '%%'" ;;
  "Kill Session")
    tmux confirm-before -p "kill-session #S? (y/n)" kill-session ;;
  "Switcher")
    tmux run-shell "$HOME/.config/tmux/scripts/switcher.sh || true" ;;
  "Last Session")
    tmux switch-client -l ;;
  "Choose Tree")
    tmux choose-tree -Zw -F "#{?pane_format,#{pane_current_command} #{pane_current_path},#{?window_format,#{window_name} (#{window_panes} panes),#{session_name} (#{session_windows} win)}}" ;;
  "Enter Copy Mode")
    tmux copy-mode ;;
  "Paste Buffer")
    tmux paste-buffer ;;
  "Yank Command Line")
    tmux run-shell -b "$HOME/.config/tmux/plugins/tmux-yank/scripts/copy_line.sh" ;;
  "Yank Pane CWD")
    tmux run-shell -b "$HOME/.config/tmux/plugins/tmux-yank/scripts/copy_pane_pwd.sh" ;;
  "URL Picker")
    tmux run-shell -b "$HOME/.config/tmux/plugins/tmux-fzf-url/fzf-url.sh '' 2000 'open' ''" ;;
  "Lazygit")
    tmux display-popup -E -w 70% -h 80% -b rounded -T '#[align=centre] Lazygit ' -d "#{pane_current_path}" lazygit ;;
  "Keybindings")
    tmux run-shell "$HOME/.config/tmux/scripts/keyb-popup.sh || true" ;;
  "Command Prompt")
    tmux command-prompt ;;
  "Display Pane Numbers")
    tmux display-panes ;;
  "Reload Config")
    tmux source-file "$HOME/.config/tmux/tmux.conf" \; display-message "Tmux config reloaded" ;;
  "Detach")
    tmux detach-client ;;
  "Break Pane to Window")
    tmux break-pane ;;
  "Break Pane to Session")
    tmux command-prompt -p "Break to session:" "run-shell \"$HOME/.config/tmux/scripts/break-pane-to-session.sh '#{pane_id}' '#{pane_current_path}' '%%'\"" ;;
  *)
    cmd=$(awk '{print $1}' <<< "$label")
    [ -n "$cmd" ] && tmux command-prompt -I "$cmd" ;;
esac
