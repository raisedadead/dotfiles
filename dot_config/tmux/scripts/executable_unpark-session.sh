#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091,SC2034

. "$(dirname "$0")/colors.sh"
. "$(dirname "$0")/session-lib.sh"

if [[ ! -d "$PARK_DIR" ]] || [[ -z "$(ls -A "$PARK_DIR"/*.park 2>/dev/null)" ]]; then
  tmux display-message "Unpark: no parked sessions"
  exit 0
fi

pick_session() {
  local files=("$PARK_DIR"/*.park)
  if [[ ${#files[@]} -eq 1 ]]; then
    basename "${files[0]}" .park
    return
  fi

  for f in "${files[@]}"; do
    local name
    name=$(basename "$f" .park)
    local wins
    wins=$(grep -c '^WINDOW=' "$f")
    local panes
    panes=$(grep -c '^PANE=' "$f")
    printf '%s\t%s win, %s panes\n' "$name" "$wins" "$panes"
  done | fzf \
    --border rounded --border-label=" Unpark Session " \
    --padding=1,2 \
    --color="$FZF_MOCHA_COLORS" \
    --no-info --reverse \
    --delimiter='\t' --with-nth=1,2 \
    --preview-window=hidden | cut -f1
}

selected=$(pick_session)
[[ -z "$selected" ]] && exit 0

parkfile="$PARK_DIR/${selected}.park"
if [[ ! -f "$parkfile" ]]; then
  tmux display-message "Unpark: file not found for '$selected'"
  exit 1
fi

if tmux has-session -t "$selected" 2>/dev/null; then
  tmux display-message "Unpark: session '$selected' already exists"
  exit 1
fi

# Pre-read pane paths indexed by window for lookup during creation
declare -A first_pane_paths
while IFS= read -r line; do
  case "$line" in
    PANE=*)
      IFS='|' read -r _wi _ _ppath _ _ <<< "${line#PANE=}"
      if [[ -z "${first_pane_paths[$_wi]:-}" ]]; then
        first_pane_paths[$_wi]="$_ppath"
      fi
      ;;
  esac
done < "$parkfile"

session=""
active_win=""
first_window=true
declare -A window_pane_count

while IFS= read -r line; do
  case "$line" in
    SESSION=*)
      session="${line#SESSION=}"
      ;;
    WINDOW=*)
      IFS='|' read -r wi wname _wlayout wactive <<< "${line#WINDOW=}"
      local_path="${first_pane_paths[$wi]:-$HOME}"
      if [[ "$first_window" == true ]]; then
        tmux new-session -d -s "$session" -n "$wname" -c "$local_path" -x "$(tput cols)" -y "$(tput lines)"
        first_window=false
      else
        tmux new-window -t "${session}:" -n "$wname" -c "$local_path"
      fi
      window_pane_count[$wi]=1
      [[ "$wactive" == "1" ]] && active_win="$wi"
      ;;
    PANE=*)
      IFS='|' read -r wi _ ppath _ _ <<< "${line#PANE=}"
      count="${window_pane_count[$wi]:-0}"
      if (( count > 1 )); then
        tmux split-window -t "${session}:${wi}" -c "${ppath:-$HOME}"
      fi
      window_pane_count[$wi]=$(( count + 1 ))
      ;;
  esac
done < "$parkfile"

# Apply saved layouts to each window
while IFS= read -r line; do
  case "$line" in
    WINDOW=*)
      IFS='|' read -r wi _ wlayout _ <<< "${line#WINDOW=}"
      tmux select-layout -t "${session}:${wi}" "$wlayout" 2>/dev/null || true
      ;;
  esac
done < "$parkfile"

if [[ -n "$active_win" ]]; then
  tmux select-window -t "${session}:${active_win}"
fi

tmux switch-client -t "$session"
rm -f "$parkfile"
tmux display-message "Unparked: $session"
