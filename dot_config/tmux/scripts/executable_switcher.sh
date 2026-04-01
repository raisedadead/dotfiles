#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2001,SC2034

SELF="$0"
# shellcheck source=colors.sh
. "$(dirname "$0")/colors.sh"

CATEGORIES=(projects sessions config zoxide search)
# Nerd Font icons via escape sequences (Edit tool drops literal PUA chars)
_ico_session=$'\U000F018D'   # nf-md-console
_ico_project=$'\U000F0770'   # nf-md-folder_open
_ico_config=$'\U000F0493'    # nf-md-cog
_ico_zoxide=$'\U000F02DA'    # nf-md-history
_ico_search=$'\U000F0349'    # nf-md-magnify
_ico_files=$'\U000F0219'     # nf-md-file_multiple
_ico_text=$'\U000F0284'      # nf-md-file_document
LABELS=("$_ico_project  Projects" "$_ico_session  Sessions" "$_ico_config  Config" "$_ico_zoxide  Zoxide" "$_ico_search  Search")
PROMPTS=("$_ico_project  Projects ❯ " "$_ico_session  Sessions ❯ " "$_ico_config  Config ❯ " "$_ico_zoxide  Zoxide ❯ " "$_ico_search  Search ❯ ")
FOOTERS=(
  "  Connect [⏎] ◆ Editor [Ctrl+E] ◆ VS Code [Ctrl+V] ◆ Preview [Ctrl+O] ◆ Category [Tab]"
  "  Switch [⏎] ◆ Kill [Ctrl+D] ◆ Preview [Ctrl+O] ◆ Category [Tab]"
  "  Connect [⏎] ◆ Editor [Ctrl+E] ◆ VS Code [Ctrl+V] ◆ Preview [Ctrl+O] ◆ Category [Tab]"
  "  Connect [⏎] ◆ Editor [Ctrl+E] ◆ VS Code [Ctrl+V] ◆ Preview [Ctrl+O] ◆ Category [Tab]"
  "  Open [⏎] ◆ Editor [Ctrl+E] ◆ VS Code [Ctrl+V] ◆ Files/Text [Ctrl+S] ◆ Preview [Ctrl+O] ◆ Category [Tab]"
)
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
    [ "$first" = "1" ] && first=0 || printf ' %s◆%s ' "$DIM" "$RST"
    if [ "$i" -eq "$idx" ]; then
      printf '%s%s%s' "$ACCENT" "${LABELS[$i]}" "$RST"
    else
      printf '%s%s%s' "$SUB" "${LABELS[$i]}" "$RST"
    fi
  done
  printf ''
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
    printf '%s\t%s%-20s%s\t%s%-16s%s %s%s%s\n' \
      "$target" "$HI" "$session" "$RST" "$SUB" "$wname" "$RST" "$DIM" "$wpath" "$RST"
  done
}

source_projects() {
  local raw_lines=()

  if [ -f "$PROJECTS_JSON" ] && command -v jq >/dev/null 2>&1; then
    # Collect scoped entries: scope|path
    while IFS='|' read -r scope base_path; do
      base_path=$(expand_tilde "$base_path")
      [ -d "$base_path" ] || continue
      local entries
      if command -v fd >/dev/null 2>&1; then
        entries=$(fd -d 1 -t d . "$base_path" 2>/dev/null | sort)
      else
        entries=$(find "$base_path" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)
      fi
      while IFS= read -r p; do
        [ -n "$p" ] && raw_lines+=("$scope|$p")
      done <<< "$entries"
    done < <(jq -r '.baseFolders[]? | "\(.scope // "Other")|\(.path)"' "$PROJECTS_JSON" 2>/dev/null)

    # Favorites
    while IFS= read -r fav; do
      fav=$(expand_tilde "$fav")
      [ -d "$fav" ] && raw_lines+=("Favorites|$fav")
    done < <(jq -r '.favorites[]? | select(.enabled != false) | .rootPath // empty' "$PROJECTS_JSON" 2>/dev/null)
  fi

  # Render with scope headers
  local last_scope=""
  for entry in "${raw_lines[@]}"; do
    local scope="${entry%%|*}"
    local p="${entry#*|}"
    local name short
    name=$(basename "$p")
    short=$(shorten "$p")

    if [ "$scope" != "$last_scope" ]; then
      [ -n "$last_scope" ] && printf '\t\n'
      printf '\t%s── %s ──%s\n' "$SUB" "$scope" "$RST"
      last_scope="$scope"
    fi
    printf '%s|%s\t%s%-24s%s\t%s%s%s\n' "$scope" "$p" "$HI" "$name" "$RST" "$DIM" "$short" "$RST"
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
    printf '%s\t%s%-20s%s\t%s%s%s\n' "$d" "$HI" "$name" "$RST" "$DIM" "$short" "$RST"
  done
}

source_zoxide() {
  if command -v zoxide >/dev/null 2>&1; then
    zoxide query -l 2>/dev/null | awk -v home="$HOME" \
      -v hi="$HI" -v dim="$DIM" -v rst="$RST" '{
      display = $0; sub("^" home, "~", display)
      n = split(display, parts, "/")
      dir = ""; for (i=1; i<n; i++) dir = dir parts[i] "/"
      printf "%s\t%s%-20s%s\t%s%s%s\n", $0, hi, parts[n], rst, dim, dir, rst
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
      printf "%s\t%s%-20s%s\t%s%s%s\n", $0, hi, parts[n], rst, dim, dir, rst
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
  local footer="${DIM}${FOOTERS[$idx]}${RST}"
  printf 'reload(%s --source %s)+change-header(%s)+change-prompt(%s)+change-footer(%s)+show-preview' \
    "$SELF" "${CATEGORIES[$idx]}" "$header" "$prompt_str" "$footer"
}

extract_path() {
  cut -f1 <<< "$1"
}

eza_tree() {
  eza --tree --level=2 --icons --color=always --group-directories-first \
    --ignore-glob='node_modules|.git|__pycache__|.next|dist|build|.cache|.turbo|vendor' \
    "$1" 2>/dev/null || ls -la "$1" 2>/dev/null
}

do_preview() {
  local entry="$1" idx cat path
  idx=$(get_index)
  cat="${CATEGORIES[$idx]}"

  case "$cat" in
    sessions)
      local target session
      target=$(extract_path "$entry")
      session="${target%%:*}"
      sesh preview "$session" 2>/dev/null || echo "No preview available"
      ;;
    projects)
      local raw
      raw=$(extract_path "$entry")
      path="${raw#*|}"
      local readme=""
      for f in "$path"/README.md "$path"/readme.md "$path"/README "$path"/README.rst; do
        [ -f "$f" ] && readme="$f" && break
      done
      if [ -n "$readme" ]; then
        bat -n --color=always --style=plain "$readme" 2>/dev/null
      else
        eza_tree "$path"
      fi
      ;;
    config)
      path=$(extract_path "$entry")
      eza_tree "$path"
      ;;
    zoxide)
      path=$(extract_path "$entry")
      if [ -d "$path" ]; then
        eza_tree "$path"
      elif [ -f "$path" ]; then
        bat -n --color=always "$path" 2>/dev/null
      fi
      ;;
    search)
      path=$(extract_path "$entry")
      local mode
      mode=$(get_search_mode)
      if [ "$mode" = "files" ] && [ -f "$path" ]; then
        bat -n --color=always "$path" 2>/dev/null
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
      tmux new-window -c "$dir" "${EDITOR:-nvim}" "+$line" "$path"
    else
      tmux new-window -c "$dir" "${EDITOR:-nvim}" "$path"
    fi
  else
    tmux new-window -c "$path" "${EDITOR:-nvim}"
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
    projects)
      local raw
      raw=$(extract_path "$entry")
      path="${raw#*|}"
      case "$key" in
        ctrl-e) open_in_editor "$path" ;;
        ctrl-v) "${VISUAL:-code}" "$path" ;;
        *)      sesh connect "$path" ;;
      esac
      ;;
    config|zoxide)
      path=$(extract_path "$entry")
      case "$key" in
        ctrl-e) open_in_editor "$path" ;;
        ctrl-v) "${VISUAL:-code}" "$path" ;;
        *)      sesh connect "$path" ;;
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
          *)      sesh connect "$stripped" ;;
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
    _ft="${DIM}  Open [⏎] ◆ Editor [Ctrl+E] ◆ VS Code [Ctrl+V] ◆ Files/Text [Ctrl+S] ◆ Preview [Ctrl+O] ◆ Category [Tab]${RST}"
    if [ "$local_mode" = "files" ]; then
      set_search_mode "text"
      printf 'reload(%s --source search)+change-prompt(%s  Text ❯ )+change-footer(%s)+hide-preview' "$SELF" "$_ico_text" "$_ft"
    else
      set_search_mode "files"
      printf 'reload(%s --source search)+change-prompt(%s  Files ❯ )+change-footer(%s)+show-preview' "$SELF" "$_ico_files" "$_ft"
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

result=$(do_source projects | fzf-tmux -p 75%,80% \
  --ansi --no-sort --no-info --cycle \
  --delimiter '\t' --with-nth '2..' --nth '1' \
  --border rounded --border-label ' Switcher ' --border-label-pos 3 --padding=1,2 \
  --color "$FZF_MOCHA_COLORS" \
  --header "$initial_header" \
  --header-first --header-border=line \
  --prompt "$_ico_project  Projects ❯ " \
  --footer "${DIM}${FOOTERS[0]}${RST}" \
  --footer-border=line \
  --preview "$SELF --preview {}" \
  --preview-window 'right:50%:wrap' \
  --bind "tab:transform($SELF --cycle next)" \
  --bind "btab:transform($SELF --cycle prev)" \
  --bind 'ctrl-o:toggle-preview' \
  --bind "ctrl-s:transform($SELF --toggle-search)" \
  --expect 'ctrl-e,ctrl-v,ctrl-d' \
  --bind 'esc:abort')

[ -z "$result" ] && exit 0

key=$(head -1 <<< "$result")
entry=$(tail -1 <<< "$result")

[ -z "$entry" ] && exit 0

do_action "$entry" "$key"
