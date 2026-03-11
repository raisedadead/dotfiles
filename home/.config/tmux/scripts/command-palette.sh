#!/usr/bin/env bash

D=$'\033[90m'  # dim (brightblack)
R=$'\033[0m'   # reset

WIDTH=50

commands() {
  local entries=(
    "Split Horizontal|Alt+d"
    "Split Vertical|Alt+D"
    "Zoom Pane|Alt+Shift+Enter"
    "Kill Pane|pfx+x"
    "Sync Panes|pfx+i"
    "New Window|Alt+t"
    "Rename Window|pfx+,"
    "Close Window|pfx+&"
    "New Session|Alt+n"
    "Rename Session|pfx+\$"
    "Kill Session|"
    "Sesh Picker|Alt+o"
    "Last Session|pfx+L"
    "Choose Tree|Alt+w"
    "Lazygit|Alt+g"
    "Keybindings|Alt+?"
    "Reload Config|pfx+r"
    "Enter Copy Mode|pfx+["
  )

  for entry in "${entries[@]}"; do
    local label="${entry%%|*}"
    local hint="${entry#*|}"
    if [ -n "$hint" ]; then
      printf "  %-${WIDTH}s ${D}%s${R}\n" "$label" "$hint"
    else
      printf "  %-${WIDTH}s\n" "$label"
    fi
  done
}

tmux_commands() {
  printf '  %s─── tmux commands ───%s\n' "$D" "$R"
  tmux lscm -F '#{command_list_name}#{?command_list_alias, (#{command_list_alias}),}' \
    | while IFS= read -r cmd; do
        printf "  ${D}%s${R}\n" "$cmd"
      done
}

selected=$({ commands; tmux_commands; } | fzf-tmux -p 53%,60% \
  --no-sort --no-info --ansi --border=rounded --padding=0,1 \
  --color='header:8,pointer:magenta,prompt:magenta,border:white' \
  --prompt '  ' \
  --bind 'esc:abort')

[ -z "$selected" ] && exit 0

label=$(sed -e 's/\x1b\[[0-9;]*m//g' -e 's/^  //' -e 's/[[:space:]]*$//' -e 's/[[:space:]]\{2,\}.*//' <<< "$selected")

case "$label" in
  "Split Horizontal")
    tmux split-window -h -c "#{pane_current_path}" ;;
  "Split Vertical")
    tmux split-window -v -c "#{pane_current_path}" ;;
  "Zoom Pane")
    tmux resize-pane -Z ;;
  "Kill Pane")
    tmux kill-pane ;;
  "Sync Panes")
    tmux setw synchronize-panes ;;
  "New Window")
    tmux new-window -c "#{pane_current_path}" ;;
  "Rename Window")
    tmux command-prompt -I "#W" "rename-window -- '%%'" ;;
  "Close Window")
    tmux confirm-before -p "kill-window #W? (y/n)" kill-window ;;
  "New Session")
    tmux display-popup -E -w 30% -h 3 -b rounded "$HOME/.config/tmux/scripts/new-session-popup.sh" ;;
  "Rename Session")
    tmux command-prompt -I "#S" "rename-session -- '%%'" ;;
  "Kill Session")
    tmux confirm-before -p "kill-session #S? (y/n)" kill-session ;;
  "Sesh Picker")
    tmux run-shell "$HOME/.config/tmux/scripts/sesh-popup.sh || true" ;;
  "Last Session")
    tmux run-shell "sesh last" ;;
  "Choose Tree")
    tmux choose-tree -Zw ;;
  "Lazygit")
    tmux display-popup -E -w 70% -h 80% -b rounded -d "#{pane_current_path}" lazygit ;;
  "Keybindings")
    tmux run-shell "$HOME/.config/tmux/scripts/keyb-popup.sh || true" ;;
  "Reload Config")
    tmux source-file "$HOME/.config/tmux/tmux.conf" \; display-message "Tmux config reloaded" ;;
  "Enter Copy Mode")
    tmux copy-mode ;;
  "─── tmux commands ───") ;;
  *)
    cmd=$(awk '{print $1}' <<< "$label")
    [ -n "$cmd" ] && tmux command-prompt -I "$cmd" ;;
esac
