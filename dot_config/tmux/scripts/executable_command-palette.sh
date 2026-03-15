#!/usr/bin/env bash

D=$'\033[90m'  # dim (brightblack)
Y=$'\033[33m'  # yellow
R=$'\033[0m'   # reset

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
  action "o" "Sesh Picker" "Switch or create session"
  action "g" "Lazygit" "Git TUI popup"
  action "d" "Split Right" "Pane to the right"
  action "D" "Split Down" "Pane below"
  action "f" "Zoom Toggle" "Toggle fullscreen"
  action "w" "Choose Tree" "Browse sessions/windows"
  action "n" "New Session" "Named session prompt"
  action "k" "Keybindings" "Search all keybinds"
  action "r" "Reload Config" "Re-source tmux.conf"
  section "More"
  action "1" "Kill Pane" "Close active pane"
  action "2" "New Window" "Open in cwd"
  action "3" "Rename Window" "Set window title"
  action "4" "Kill Window" "Close with confirm"
  action "5" "Last Session" "Toggle previous session"
  action "6" "Enter Copy Mode" "Vi-style selection"
  action "7" "Paste Buffer" "Paste last copied text"
  action "8" "URL Picker" "Open URLs from scrollback"
  action "9" "Command Prompt" "tmux command line"
  section "Other"
  entry "Equalize Vertical" "pfx+e" "Stack panes evenly"
  entry "Equalize Horizontal" "pfx+E" "Tile panes evenly"
  entry "Sync Panes" "pfx+i" "Toggle input sync"
  entry "Rename Session" "pfx+\$" "Set session title"
  entry "Kill Session" "" "Destroy with confirm"
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
  --bind "1:transform:[ -z {q} ] && echo 'become(echo __KILL_PANE__)' || echo 'put(1)'"
  --bind "2:transform:[ -z {q} ] && echo 'become(echo __NEW_WINDOW__)' || echo 'put(2)'"
  --bind "3:transform:[ -z {q} ] && echo 'become(echo __RENAME_WINDOW__)' || echo 'put(3)'"
  --bind "4:transform:[ -z {q} ] && echo 'become(echo __KILL_WINDOW__)' || echo 'put(4)'"
  --bind "5:transform:[ -z {q} ] && echo 'become(echo __LAST_SESSION__)' || echo 'put(5)'"
  --bind "6:transform:[ -z {q} ] && echo 'become(echo __COPY_MODE__)' || echo 'put(6)'"
  --bind "7:transform:[ -z {q} ] && echo 'become(echo __PASTE__)' || echo 'put(7)'"
  --bind "8:transform:[ -z {q} ] && echo 'become(echo __URL_PICKER__)' || echo 'put(8)'"
  --bind "9:transform:[ -z {q} ] && echo 'become(echo __CMD_PROMPT__)' || echo 'put(9)'"
)

CTX=$(tmux display-message -p '#S • window #{window_index}/#{session_windows} • #{window_panes} panes')

selected=$({ commands; tmux_commands; } | fzf-tmux -p 40%,45% \
  --no-sort --no-info --ansi --border=rounded --border-label=' Commands ' --padding=1,2 \
  --header-first --header-border=line \
  --header "$D  $CTX$R" \
  --color='header:8,pointer:yellow,prompt:yellow,border:white,label:yellow' \
  --prompt '  ' \
  "${BINDS[@]}" \
  --bind 'esc:abort')

[ -z "$selected" ] && exit 0

# Quick shortcut dispatch
case "$selected" in
  __SESH__)
    tmux run-shell "$HOME/.config/tmux/scripts/sesh-popup.sh || true"; exit 0 ;;
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
  __KILL_PANE__)
    tmux kill-pane; exit 0 ;;
  __NEW_WINDOW__)
    tmux new-window -c "#{pane_current_path}"; exit 0 ;;
  __RENAME_WINDOW__)
    tmux command-prompt -I "#W" "rename-window -- '%%'"; exit 0 ;;
  __KILL_WINDOW__)
    tmux confirm-before -p "kill-window #W? (y/n)" kill-window; exit 0 ;;
  __LAST_SESSION__)
    tmux run-shell "sesh last"; exit 0 ;;
  __COPY_MODE__)
    tmux copy-mode; exit 0 ;;
  __PASTE__)
    tmux paste-buffer; exit 0 ;;
  __URL_PICKER__)
    tmux run-shell -b "$HOME/.config/tmux/plugins/tmux-fzf-url/fzf-url.sh '' 2000 'open' ''"; exit 0 ;;
  __CMD_PROMPT__)
    tmux command-prompt; exit 0 ;;
esac

# Normal selection dispatch
label=$(sed -e 's/\x1b\[[0-9;]*m//g' -e 's/^  //' -e 's/[[:space:]]*$//' -e 's/[[:space:]]\{2,\}.*//' <<< "$selected")

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
    tmux setw synchronize-panes ;;
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
  "Sesh Picker")
    tmux run-shell "$HOME/.config/tmux/scripts/sesh-popup.sh || true" ;;
  "Last Session")
    tmux run-shell "sesh last" ;;
  "Choose Tree")
    tmux choose-tree -Zw -F "#{?pane_format,#{pane_current_command} #{pane_current_path},#{?window_format,#{window_name} (#{window_panes} panes),#{session_name} (#{session_windows} win)}}" ;;
  "Navigate Pane")
    tmux display-message "Use Ctrl+Alt+h/j/k/l to navigate panes" ;;
  "Resize Pane")
    tmux display-message "Use pfx+H/J/K/L to resize panes" ;;
  "Next Window")
    tmux next-window ;;
  "Previous Window")
    tmux previous-window ;;
  "Window 1-9")
    tmux display-message "Use Alt+1..9 for direct window access" ;;
  "Cycle Session Next")
    tmux switch-client -n ;;
  "Cycle Session Prev")
    tmux switch-client -p ;;
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
  *)
    cmd=$(awk '{print $1}' <<< "$label")
    [ -n "$cmd" ] && tmux command-prompt -I "$cmd" ;;
esac
