#!/usr/bin/env bash

D=$'\033[90m'  # dim (brightblack)
R=$'\033[0m'   # reset

W1=22  # label width
W2=16  # hint width

section() {
  printf "  ${D}── %s ──${R}\n" "$1"
}

entry() {
  local label="$1" hint="$2" desc="$3"
  if [ -n "$hint" ]; then
    printf "  %-${W1}s ${D}%-${W2}s %s${R}\n" "$label" "$hint" "$desc"
  else
    printf "  %-${W1}s ${D}%-${W2}s %s${R}\n" "$label" "" "$desc"
  fi
}

commands() {
  section "Panes"
  entry "Split Horizontal" "Alt+d" "Pane to the right"
  entry "Split Vertical" "Alt+D" "Pane below"
  entry "Zoom Pane" "Alt+Shift+Enter" "Toggle fullscreen"
  entry "Equalize Vertical" "pfx+e" "Stack panes evenly"
  entry "Equalize Horizontal" "pfx+E" "Tile panes evenly"
  entry "Kill Pane" "pfx+x" "Close active pane"
  entry "Sync Panes" "pfx+i" "Toggle input sync"
  section "Windows"
  entry "New Window" "Alt+t" "Open in cwd"
  entry "Rename Window" "pfx+," "Set window title"
  entry "Kill Window" "pfx+&" "Close with confirm"
  section "Sessions"
  entry "New Session" "Alt+n" "Named session prompt"
  entry "Rename Session" "pfx+\$" "Set session title"
  entry "Kill Session" "" "Destroy with confirm"
  entry "Sesh Picker" "Alt+o" "Switch or create session"
  entry "Last Session" "pfx+S" "Toggle previous session"
  entry "Choose Tree" "Alt+w" "Browse sessions/windows"
  section "Navigation"
  entry "Navigate Pane" "Ctrl+Alt+h/j/k/l" "Seamless vim/tmux nav"
  entry "Resize Pane" "pfx+H/J/K/L" "Repeatable pane resize"
  entry "Next Window" "Alt+." "Cycle forward"
  entry "Previous Window" "Alt+," "Cycle backward"
  entry "Window 1-9" "Alt+1..9" "Direct window access"
  entry "Cycle Session Next" "Alt+Tab" "Cycle forward"
  entry "Cycle Session Prev" "Alt+Shift+Tab" "Cycle backward"
  section "Clipboard"
  entry "Enter Copy Mode" "pfx+[" "Vi-style selection"
  entry "Paste Buffer" "pfx+]" "Paste last copied text"
  entry "Yank Command Line" "pfx+y" "Copy cmdline to clipboard"
  entry "Yank Pane CWD" "pfx+Y" "Copy cwd to clipboard"
  section "Plugins"
  entry "URL Picker" "pfx+u" "Open URLs from scrollback"
  entry "Menus" "pfx+\\" "Context menus (tmux-menus)"
  section "Tools"
  entry "Lazygit" "Alt+g" "Git TUI popup"
  entry "Command Palette" "Alt+p" "This menu"
  entry "Keybindings" "Alt+?" "Search all keybinds"
  entry "Command Prompt" "pfx+:" "tmux command line"
  entry "Display Pane Numbers" "pfx+q" "Show pane indices"
  entry "Reload Config" "pfx+r" "Re-source tmux.conf"
  entry "Detach" "pfx+d" "Detach from session"
}

tmux_commands() {
  section "tmux commands"
  tmux lscm -F '#{command_list_name}#{?command_list_alias, (#{command_list_alias}),}' \
    | while IFS= read -r cmd; do
        printf "  ${D}%s${R}\n" "$cmd"
      done
}

CTX=$(tmux display-message -p '#S • window #{window_index}/#{session_windows} • #{window_panes} panes')

selected=$({ commands; tmux_commands; } | fzf-tmux -p 40%,45% \
  --no-sort --no-info --ansi --border=rounded --border-label=' Commands ' --padding=1,2 \
  --header-first --header-border=line \
  --header "$D  $CTX$R" \
  --color='header:8,pointer:yellow,prompt:yellow,border:white,label:yellow' \
  --prompt '  ' \
  --bind 'esc:abort')

[ -z "$selected" ] && exit 0

label=$(sed -e 's/\x1b\[[0-9;]*m//g' -e 's/^  //' -e 's/[[:space:]]*$//' -e 's/[[:space:]]\{2,\}.*//' <<< "$selected")

case "$label" in
  "──"*) ;;
  "Split Horizontal")
    tmux split-window -h -c "#{pane_current_path}" ;;
  "Split Vertical")
    tmux split-window -v -c "#{pane_current_path}" ;;
  "Zoom Pane")
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
  "Menus")
    tmux run-shell "$HOME/.config/tmux/plugins/tmux-menus/items/main.sh" ;;
  "Lazygit")
    tmux display-popup -E -w 70% -h 80% -b rounded -T '#[align=centre] Lazygit ' -d "#{pane_current_path}" lazygit ;;
  "Command Palette")
    tmux run-shell "$HOME/.config/tmux/scripts/command-palette.sh || true" ;;
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
