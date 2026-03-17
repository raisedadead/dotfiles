#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2001,SC2034

SELF="$0"
# shellcheck source=colors.sh
. "$(dirname "$0")/colors.sh"

CATEGORIES=(sessions projects config zoxide search)
# Nerd Font icons via escape sequences (Edit tool drops literal PUA chars)
_ico_session=$'\U000F018D'   # nf-md-console
_ico_project=$'\U000F0770'   # nf-md-folder_open
_ico_config=$'\U000F0493'    # nf-md-cog
_ico_zoxide=$'\U000F02DA'    # nf-md-history
_ico_search=$'\U000F0349'    # nf-md-magnify
_ico_files=$'\U000F0219'     # nf-md-file_multiple
_ico_text=$'\U000F0284'      # nf-md-file_document
LABELS=("$_ico_session  Sessions" "$_ico_project  Projects" "$_ico_config  Config" "$_ico_zoxide  Zoxide" "$_ico_search  Search")
PROMPTS=("$_ico_session  Sessions ❯ " "$_ico_project  Projects ❯ " "$_ico_config  Config ❯ " "$_ico_zoxide  Zoxide ❯ " "$_ico_search  Search ❯ ")
PROJECTS_JSON="$HOME/.config/switcher/projects.json"

DIM="$CLR_DIM"
HI="$CLR_HI"
ACCENT="$CLR_ACCENT"
SUB="$CLR_SUB"
RST="$CLR_RST"

# Fixed state file paths — must be deterministic across fzf subprocesses
SWITCHER_STATE="/tmp/switcher.state"
SEARCH_MODE="/tmp/switcher-search-mode"

get_index() {
  cat "$SWITCHER_STATE" 2>/dev/null || echo 0
}

set_index() {
  echo "$1" > "$SWITCHER_STATE"
}

make_header() {
  local idx="$1" first=1
  printf '  '
  for i in "${!CATEGORIES[@]}"; do
    [ "$first" = "1" ] && first=0 || printf '  %s◆%s  ' "$DIM" "$RST"
    if [ "$i" -eq "$idx" ]; then
      printf '%s%s%s' "$ACCENT" "${LABELS[$i]}" "$RST"
    else
      printf '%s%s%s' "$SUB" "${LABELS[$i]}" "$RST"
    fi
  done
  printf '  %stab ⇥%s' "$DIM" "$RST"
}

sesh_connect() {
  local path="$1"
  if command -v sesh >/dev/null 2>&1; then
    sesh connect "$path"
  else
    local name
    name=$(basename "$path")
    if tmux has-session -t "=$name" 2>/dev/null; then
      tmux switch-client -t "=$name"
    else
      tmux new-session -d -s "$name" -c "$path"
      tmux switch-client -t "=$name"
    fi
  fi
}

expand_tilde() {
  echo "${1/#\~/$HOME}"
}

shorten() {
  sed "s|^$HOME|~|" <<< "$1"
}

source_sessions() {
  tmux list-windows -a -F '#{session_name}:#{window_index}|#{window_name}|#{pane_current_path}' 2>/dev/null | while IFS='|' read -r target wname wpath; do
    local session="${target%%:*}"
    wpath=$(shorten "$wpath")
    printf '%s\t%s%-20s%s %s%-16s%s %s%s%s\n' \
      "$target" "$HI" "$session" "$RST" "$SUB" "$wname" "$RST" "$DIM" "$wpath" "$RST"
  done
}

source_projects() {
  local base_folders=() favorites=()

  if [ -f "$PROJECTS_JSON" ] && command -v jq >/dev/null 2>&1; then
    while IFS= read -r base; do
      base=$(expand_tilde "$base")
      [ -d "$base" ] && base_folders+=("$base")
    done < <(jq -r '.baseFolders[]? // empty' "$PROJECTS_JSON" 2>/dev/null)

    while IFS= read -r fav; do
      fav=$(expand_tilde "$fav")
      [ -d "$fav" ] && favorites+=("$fav")
    done < <(jq -r '.favorites[]? | select(.enabled != false) | .rootPath // empty' "$PROJECTS_JSON" 2>/dev/null)
  fi

  if [ ${#base_folders[@]} -eq 0 ] && [ ${#favorites[@]} -eq 0 ]; then
    [ -d "$HOME/DEV" ] && base_folders+=("$HOME/DEV")
  fi

  {
    for base in "${base_folders[@]}"; do
      if command -v fd >/dev/null 2>&1; then
        fd -d 1 -t d . "$base" 2>/dev/null
      else
        find "$base" -maxdepth 1 -mindepth 1 -type d 2>/dev/null
      fi
    done
    for fav in "${favorites[@]}"; do
      echo "$fav"
    done
  } | sort -u | while IFS= read -r p; do
    local name short
    name=$(basename "$p")
    short=$(shorten "$p")
    printf '%s\t%s%-24s%s %s%s%s\n' "$p" "$HI" "$name" "$RST" "$DIM" "$short" "$RST"
  done
}

source_config() {
  local dirs=()
  if [ -f "$PROJECTS_JSON" ] && command -v jq >/dev/null 2>&1; then
    while IFS= read -r dir; do
      dir=$(expand_tilde "$dir")
      [ -d "$dir" ] && dirs+=("$dir")
    done < <(jq -r '.configDirs[]? // empty' "$PROJECTS_JSON" 2>/dev/null)
  fi
  if [ ${#dirs[@]} -eq 0 ]; then
    local fallback=("$HOME/.config/nvim" "$HOME/.config/tmux" "$HOME/.config/ghostty" "$HOME/.dotfiles")
    for d in "${fallback[@]}"; do [ -d "$d" ] && dirs+=("$d"); done
  fi
  for d in "${dirs[@]}"; do
    local name short
    name=$(basename "$d")
    short=$(shorten "$d")
    printf '%s\t%s%-20s%s %s%s%s\n' "$d" "$HI" "$name" "$RST" "$DIM" "$short" "$RST"
  done
}

source_zoxide() {
  if command -v zoxide >/dev/null 2>&1; then
    zoxide query -l 2>/dev/null | awk -v home="$HOME" \
      -v hi="$HI" -v dim="$DIM" -v rst="$RST" '{
      display = $0; sub("^" home, "~", display)
      n = split(display, parts, "/")
      dir = ""; for (i=1; i<n; i++) dir = dir parts[i] "/"
      printf "%s\t%s%s%s%s%s\n", $0, dim, dir, hi, parts[n], rst
    }'
  fi
}

get_search_mode() {
  cat "$SEARCH_MODE" 2>/dev/null || echo "files"
}

set_search_mode() {
  echo "$1" > "$SEARCH_MODE"
}

source_search() {
  local mode base
  mode=$(get_search_mode)
  base=$(tmux display-message -p '#{pane_current_path}' 2>/dev/null || echo "$HOME")
  if [ "$mode" = "text" ]; then
    rg --no-heading --line-number --color=always . "$base" 2>/dev/null | head -5000 | awk '{
      clean = $0; gsub(/\033\[[0-9;]*m/, "", clean)
      printf "%s\t%s\n", clean, $0
    }'
  else
    fd --max-depth 4 --type f --type d . "$base" 2>/dev/null | head -5000 | awk -v home="$HOME" \
      -v hi="$HI" -v dim="$DIM" -v rst="$RST" '{
      display = $0; sub("^" home, "~", display)
      n = split(display, parts, "/")
      dir = ""; for (i=1; i<n; i++) dir = dir parts[i] "/"
      printf "%s\t%s%s%s%s%s\n", $0, dim, dir, hi, parts[n], rst
    }'
  fi
}

do_source() {
  local cat="$1"
  case "$cat" in
    sessions) source_sessions ;;
    projects) source_projects ;;
    config)   source_config ;;
    zoxide)   source_zoxide ;;
    search)   source_search ;;
    *)        echo "Unknown category: $cat" >&2; exit 1 ;;
  esac
}

do_cycle() {
  local direction="$1" idx total
  idx=$(get_index)
  total=${#CATEGORIES[@]}
  if [ "$direction" = "next" ]; then
    idx=$(( (idx + 1) % total ))
  else
    idx=$(( (idx - 1 + total) % total ))
  fi
  set_index "$idx"
  local header prompt_str
  header=$(make_header "$idx")
  if [ "${CATEGORIES[$idx]}" = "search" ]; then
    local mode
    mode=$(get_search_mode)
    [ "$mode" = "text" ] && prompt_str="$_ico_text  Text ❯ " || prompt_str="$_ico_files  Files ❯ "
  else
    prompt_str="${PROMPTS[$idx]}"
  fi
  printf 'reload(%s --source %s)+change-header(%s)+change-prompt(%s)' \
    "$SELF" "${CATEGORIES[$idx]}" "$header" "$prompt_str"
}

extract_path() {
  cut -f1 <<< "$1"
}

eza_preview() {
  eza --all --git --icons --color=always --group-directories-first "$1" 2>/dev/null || ls -la "$1" 2>/dev/null
}

do_preview() {
  local entry="$1" idx cat path
  idx=$(get_index)
  cat="${CATEGORIES[$idx]}"

  case "$cat" in
    sessions)
      local target
      target=$(extract_path "$entry")
      tmux capture-pane -t "$target" -p -e 2>/dev/null || echo "No preview available"
      ;;
    projects|config|zoxide)
      path=$(extract_path "$entry")
      eza_preview "$path"
      ;;
    search)
      local stripped mode
      stripped=$(sed 's/\x1b\[[0-9;]*m//g' <<< "$entry")
      mode=$(get_search_mode)
      if [ "$mode" = "text" ]; then
        local file line
        file=$(cut -d: -f1 <<< "$stripped")
        line=$(cut -d: -f2 <<< "$stripped")
        bat -n --color=always --highlight-line "$line" "$file" 2>/dev/null
      elif [ -d "$stripped" ]; then
        eza_preview "$stripped"
      elif [ -f "$stripped" ]; then
        bat -n --color=always "$stripped" 2>/dev/null || head -100 "$stripped" 2>/dev/null
      fi
      ;;
  esac
}

open_in_editor() {
  local path="$1" line="${2:-}"
  local dir
  if [ -f "$path" ]; then
    dir=$(dirname "$path")
    if [ -n "$line" ]; then
      tmux new-window -c "$dir" -n "${EDITOR##*/}" "${EDITOR:-nvim}" "+$line" "$path"
    else
      tmux new-window -c "$dir" -n "${EDITOR##*/}" "${EDITOR:-nvim}" "$path"
    fi
  else
    tmux new-window -c "$path" -n "${EDITOR##*/}" "${EDITOR:-nvim}"
  fi
}

do_action() {
  local entry="$1" key="${2:-}" idx cat path
  idx=$(get_index)
  cat="${CATEGORIES[$idx]}"

  case "$cat" in
    sessions)
      local target session window
      target=$(extract_path "$entry")
      session="${target%%:*}"
      window="${target#*:}"
      case "$key" in
        ctrl-d)
          tmux kill-session -t "=$session" ;;
        *)
          tmux switch-client -t "=$session"
          tmux select-window -t "${session}:${window}"
          ;;
      esac
      ;;
    projects|config|zoxide)
      path=$(extract_path "$entry")
      case "$key" in
        ctrl-e) open_in_editor "$path" ;;
        ctrl-v) "${VISUAL:-code}" "$path" ;;
        *)      sesh_connect "$path" ;;
      esac
      ;;
    search)
      local stripped mode
      stripped=$(sed 's/\x1b\[[0-9;]*m//g' <<< "$entry")
      mode=$(get_search_mode)
      if [ "$mode" = "text" ]; then
        local file line
        file=$(cut -d: -f1 <<< "$stripped")
        line=$(cut -d: -f2 <<< "$stripped")
        case "$key" in
          ctrl-v) "${VISUAL:-code}" --goto "$file:$line" ;;
          *)      open_in_editor "$file" "$line" ;;
        esac
      elif [ -d "$stripped" ]; then
        case "$key" in
          ctrl-e) open_in_editor "$stripped" ;;
          ctrl-v) "${VISUAL:-code}" "$stripped" ;;
          *)      sesh_connect "$stripped" ;;
        esac
      elif [ -f "$stripped" ]; then
        case "$key" in
          ctrl-v) "${VISUAL:-code}" "$stripped" ;;
          *)      open_in_editor "$stripped" ;;
        esac
      fi
      ;;
  esac
}

# Subcommand dispatch
case "${1:-}" in
  --source)
    do_source "$2"
    exit ;;
  --cycle)
    do_cycle "$2"
    exit ;;
  --toggle-search)
    # Only toggle if currently on the Search category
    cur_cat=$(get_index)
    if [ "${CATEGORIES[$cur_cat]}" != "search" ]; then
      exit 0
    fi
    local_mode=$(get_search_mode)
    if [ "$local_mode" = "files" ]; then
      set_search_mode "text"
      printf 'reload(%s --source search)+change-prompt(%s  Text ❯ )' "$SELF" "$_ico_text"
    else
      set_search_mode "files"
      printf 'reload(%s --source search)+change-prompt(%s  Files ❯ )' "$SELF" "$_ico_files"
    fi
    exit ;;
  --preview)
    do_preview "$2"
    exit ;;
esac

# Main entry: launch fzf-tmux
set_index 0
set_search_mode "files"
trap 'rm -f "$SWITCHER_STATE" "$SEARCH_MODE"' EXIT

initial_header=$(make_header 0)

result=$(do_source sessions | fzf-tmux -p 55%,65% \
  --ansi --no-sort --no-info --cycle \
  --delimiter '\t' --with-nth '2..' \
  --border rounded --border-label ' Switcher ' --border-label-pos 3 --padding=1,2 \
  --color "$FZF_MOCHA_COLORS" \
  --header "$initial_header" \
  --header-first --header-border=line \
  --prompt "$_ico_session  Sessions ❯ " \
  --preview "$SELF --preview {}" \
  --preview-window 'right:50%:wrap:hidden' \
  --bind "tab:transform($SELF --cycle next)" \
  --bind "btab:transform($SELF --cycle prev)" \
  --bind 'ctrl-o:toggle-preview' \
  --bind "ctrl-s:transform($SELF --toggle-search)" \
  --bind 'alt-1:pos(1)+accept' \
  --bind 'alt-2:pos(2)+accept' \
  --bind 'alt-3:pos(3)+accept' \
  --bind 'alt-4:pos(4)+accept' \
  --bind 'alt-5:pos(5)+accept' \
  --bind 'alt-6:pos(6)+accept' \
  --bind 'alt-7:pos(7)+accept' \
  --bind 'alt-8:pos(8)+accept' \
  --bind 'alt-9:pos(9)+accept' \
  --expect 'ctrl-e,ctrl-v,ctrl-d' \
  --bind 'esc:abort')

[ -z "$result" ] && exit 0

key=$(head -1 <<< "$result")
entry=$(tail -1 <<< "$result")

[ -z "$entry" ] && exit 0

do_action "$entry" "$key"
