#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2155

SELF="$0"
# shellcheck source=colors.sh
. "$(dirname "$0")/colors.sh"

# Nerd Font icons via escape sequences (Write tool drops literal PUA chars)
_ico_session=$'\U000F018D'   # nf-md-console
_ico_project=$'\U000F0770'   # nf-md-folder_open
_ico_config=$'\U000F0493'    # nf-md-cog
_ico_zoxide=$'\U000F02DA'    # nf-md-history
_ico_search=$'\U000F0349'    # nf-md-magnify
_ico_files=$'\U000F0219'     # nf-md-file_multiple
_ico_text=$'\U000F0284'      # nf-md-file_document

DIM="$CLR_DIM"
HI="$CLR_HI"
ACCENT="$CLR_ACCENT"
SUB="$CLR_SUB"
RST="$CLR_RST"

_CLR_TMUX="$CLR_GREEN"
_CLR_PROJ="$CLR_HI"
_CLR_CONF="$CLR_ACCENT"
_CLR_ZOX="$CLR_MAUVE"

PROJECTS_JSON="$HOME/.config/switcher/projects.json"

expand_tilde() { echo "${1/#\~/$HOME}"; }
shorten()      { echo "${1/#$HOME/\~}"; }

# Render one fzf display line.
# Args: cat, target, path
# Output (tab-delimited):
#   col 1 (hidden): cat|target|path
#   col 2: icon + name (colored)
#   col 3: category label (colored, 7 chars)
#   col 4: short path (dim)
render_line() {
  local cat="$1" target="$2" path="$3"
  local name short icon cat_label cat_color
  short=$(shorten "$path")
  case "$cat" in
    tmux) name="${target%%:*}"; icon="$_ico_session"; cat_label="session"; cat_color="$_CLR_TMUX" ;;
    proj) name=$(basename "$path"); icon="$_ico_project"; cat_label="project"; cat_color="$_CLR_PROJ" ;;
    conf) name=$(basename "$path"); icon="$_ico_config";  cat_label="config";  cat_color="$_CLR_CONF" ;;
    zox)  name=$(basename "$path"); icon="$_ico_zoxide";  cat_label="zoxide";  cat_color="$_CLR_ZOX" ;;
    *) return ;;
  esac
  printf '%s|%s|%s\t%s%s  %-20s%s\t%s%-7s%s\t%s%s%s\n' \
    "$cat" "$target" "$path" \
    "$HI" "$icon" "$name" "$RST" \
    "$cat_color" "$cat_label" "$RST" \
    "$DIM" "$short" "$RST"
}

# Reads "score|cat|target|path" from stdin, emits rendered fzf lines.
render_all() {
  while IFS='|' read -r _score cat target path; do
    render_line "$cat" "$target" "$path"
  done
}

# ── Data Sources ──────────────────────────────────────────────────────────────

# Merged, deduplicated, frecency-ranked list.
# Outputs: score|cat|target|path  (plain text, no ANSI), sorted descending.
#
# Priority (wins on same path): tmux(1) > proj(2) > conf(3) > zox(4)
# Score: tmux uses session recency buckets; others inherit from zoxide, with
#        conf/proj floors so they stay visible even if not recently visited.
_source_all_raw() {
  local tmpfile now
  tmpfile=$(mktemp /tmp/switcher-merge.XXXXXX)
  now=$(date +%s)

  {
    # Zoxide (priority 4 — baseline ranking for all directories)
    zoxide query --list --score 2>/dev/null | while read -r score path; do
      [[ -d "$path" ]] || continue
      printf '%s|4|zox||%s\n' "$score" "$path"
    done

    # Config dirs (priority 3, floor score 50)
    local dirs=()
    if [[ -f "$PROJECTS_JSON" ]] && command -v jq >/dev/null 2>&1; then
      while IFS= read -r d; do
        d=$(expand_tilde "$d"); [[ -d "$d" ]] && dirs+=("$d")
      done < <(jq -r '.configDirs[]? // empty' "$PROJECTS_JSON" 2>/dev/null)
    fi
    [[ ${#dirs[@]} -eq 0 ]] && dirs=(
      "$HOME/.config/nvim" "$HOME/.config/tmux"
      "$HOME/.config/ghostty" "$HOME/.dotfiles"
    )
    for d in "${dirs[@]}"; do
      [[ -d "$d" ]] && printf '50|3|conf||%s\n' "$d"
    done

    # Projects (priority 2, floor score 100; favorites floor 200)
    if [[ -f "$PROJECTS_JSON" ]] && command -v jq >/dev/null 2>&1; then
      while IFS='|' read -r _scope base; do
        base=$(expand_tilde "$base"); [[ -d "$base" ]] || continue
        if command -v fd >/dev/null 2>&1; then
          fd -d 1 -t d . "$base" 2>/dev/null
        else
          find "$base" -maxdepth 1 -mindepth 1 -type d 2>/dev/null
        fi | while IFS= read -r p; do
          [[ -d "$p" ]] && printf '100|2|proj||%s\n' "$p"
        done
      done < <(jq -r '.baseFolders[]? | "\(.scope // "Other")|\(.path)"' "$PROJECTS_JSON" 2>/dev/null)

      while IFS= read -r fav; do
        fav=$(expand_tilde "$fav")
        [[ -d "$fav" ]] && printf '200|2|proj||%s\n' "$fav"
      done < <(jq -r '.favorites[]? | select(.enabled != false) | .rootPath // empty' "$PROJECTS_JSON" 2>/dev/null)
    fi

    # TMux sessions (priority 1 — highest; score based on recency)
    tmux list-windows -a \
      -F '#{session_last_attached}|#{session_name}:#{window_index}|#{pane_current_path}|#{@parked}|#{window_active}' 2>/dev/null |
    while IFS='|' read -r last_attached target path parked active; do
      [[ "$parked" == "1" ]] && continue
      [[ "$active" != "1" ]] && continue
      local age=$(( now - last_attached ))
      local tmux_score
      if   (( age <   3600 )); then tmux_score=8000   # last hour
      elif (( age <  86400 )); then tmux_score=4000   # last day
      elif (( age < 604800 )); then tmux_score=1500   # last week
      else                          tmux_score=500
      fi
      printf '%s|1|tmux|%s|%s\n' "$tmux_score" "$target" "$path"
    done
  } >> "$tmpfile"

  # Merge: sort by path (k5) + priority asc (k2) so highest-priority cat comes
  # first per path group. In awk, keep that cat/target but accumulate max score.
  # Final sort by score descending.
  sort -t'|' -k5,5 -k2,2n "$tmpfile" | awk -F'|' '
  {
    score=$1+0; cat=$3; target=$4; path=$5
    if (path == last_path) {
      if (score > best_score) best_score = score
    } else {
      if (last_path != "") printf "%s|%s|%s|%s\n", best_score, best_cat, best_target, last_path
      last_path=path; best_score=score; best_cat=cat; best_target=target
    }
  }
  END { if (last_path != "") printf "%s|%s|%s|%s\n", best_score, best_cat, best_target, last_path }
  ' | sort -t'|' -k1,1 -rn

  rm -f "$tmpfile"
}

source_all() { _source_all_raw | render_all; }

source_tmux() {
  local now
  now=$(date +%s)
  tmux list-windows -a \
    -F '#{session_last_attached}|#{session_name}:#{window_index}|#{pane_current_path}|#{@parked}|#{window_active}' 2>/dev/null |
  while IFS='|' read -r last_attached target path parked active; do
    [[ "$parked" == "1" ]] && continue
    [[ "$active" != "1" ]] && continue
    local age=$(( now - last_attached ))
    local score
    if   (( age <   3600 )); then score=8000
    elif (( age <  86400 )); then score=4000
    elif (( age < 604800 )); then score=1500
    else                          score=500
    fi
    printf '%s|tmux|%s|%s\n' "$score" "$target" "$path"
  done | sort -t'|' -k1,1 -rn | while IFS='|' read -r _score cat target path; do
    render_line "$cat" "$target" "$path"
  done
}

source_proj() {
  [[ -f "$PROJECTS_JSON" ]] && command -v jq >/dev/null 2>&1 || return
  local paths=()
  while IFS='|' read -r _scope base; do
    base=$(expand_tilde "$base"); [[ -d "$base" ]] || continue
    if command -v fd >/dev/null 2>&1; then
      while IFS= read -r p; do [[ -d "$p" ]] && paths+=("$p"); done \
        < <(fd -d 1 -t d . "$base" 2>/dev/null | sort)
    else
      while IFS= read -r p; do [[ -d "$p" ]] && paths+=("$p"); done \
        < <(find "$base" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)
    fi
  done < <(jq -r '.baseFolders[]? | "\(.scope // "Other")|\(.path)"' "$PROJECTS_JSON" 2>/dev/null)

  # Favorites first
  while IFS= read -r fav; do
    fav=$(expand_tilde "$fav")
    [[ -d "$fav" ]] && render_line "proj" "" "$fav"
  done < <(jq -r '.favorites[]? | select(.enabled != false) | .rootPath // empty' "$PROJECTS_JSON" 2>/dev/null)

  for p in "${paths[@]}"; do render_line "proj" "" "$p"; done
}

source_conf() {
  local dirs=()
  if [[ -f "$PROJECTS_JSON" ]] && command -v jq >/dev/null 2>&1; then
    while IFS= read -r d; do
      d=$(expand_tilde "$d"); [[ -d "$d" ]] && dirs+=("$d")
    done < <(jq -r '.configDirs[]? // empty' "$PROJECTS_JSON" 2>/dev/null)
  fi
  [[ ${#dirs[@]} -eq 0 ]] && dirs=(
    "$HOME/.config/nvim" "$HOME/.config/tmux"
    "$HOME/.config/ghostty" "$HOME/.dotfiles"
  )
  for d in "${dirs[@]}"; do [[ -d "$d" ]] && render_line "conf" "" "$d"; done
}

source_zox() {
  zoxide query --list --score 2>/dev/null | while read -r _score path; do
    [[ -d "$path" ]] && render_line "zox" "" "$path"
  done
}

# Search source. mode = "files" (default) or "text".
#
# Internal format (col 1):
#   files: search||/path/to/file
#   text:  search|LINE_NUMBER|/path/to/file
#
# target is empty for files (path is the only key needed),
# and holds the line number for text (so do_action can jump directly).
source_search() {
  local mode="${1:-files}"
  local base
  base=$(tmux display-message -p '#{pane_current_path}' 2>/dev/null || echo "$HOME")

  if [[ "$mode" == "text" ]]; then
    rg --no-heading --line-number --color=always . "$base" 2>/dev/null | head -5000 | \
    while IFS= read -r line; do
      local clean file lineno
      # shellcheck disable=SC2001  # regex char class — not replaceable with ${//}
      clean=$(sed 's/\x1b\[[0-9;]*m//g' <<< "$line")
      file=$(cut -d: -f1 <<< "$clean")
      lineno=$(cut -d: -f2 <<< "$clean")
      printf 'search|%s|%s\t%s%s  %s\n' "$lineno" "$file" "$HI" "$_ico_text" "$line"
    done
  else
    fd --max-depth 4 --type f --type d . "$base" 2>/dev/null | head -5000 | \
    while IFS= read -r p; do
      local short name
      short=$(shorten "$p")
      name=$(basename "$p")
      printf 'search||%s\t%s%s  %-22s%s\t%ssrch%s\t%s%s%s\n' \
        "$p" "$HI" "$_ico_files" "$name" "$RST" \
        "$DIM" "$RST" "$DIM" "$short" "$RST"
    done
  fi
}

do_source() {
  case "$1" in
    all)    source_all ;;
    tmux)   source_tmux ;;
    proj)   source_proj ;;
    conf)   source_conf ;;
    zox)    source_zox ;;
    search) source_search "${2:-files}" ;;
    *)      echo "Unknown source: $1" >&2; exit 1 ;;
  esac
}

# ── Helpers ───────────────────────────────────────────────────────────────────

_internal()      { cut -f1 <<< "$1"; }
extract_cat()    { _internal "$1" | cut -d'|' -f1; }
extract_target() { _internal "$1" | cut -d'|' -f2; }
extract_path()   { _internal "$1" | cut -d'|' -f3; }

eza_tree() {
  eza --tree --level=2 --icons --color=always --group-directories-first \
    --ignore-glob='node_modules|.git|__pycache__|.next|dist|build|.cache|.turbo|vendor' \
    "$1" 2>/dev/null || ls -la "$1" 2>/dev/null
}

# ── Preview ───────────────────────────────────────────────────────────────────

do_preview() {
  local entry="$1"
  local cat target path
  cat=$(extract_cat "$entry")
  target=$(extract_target "$entry")
  path=$(extract_path "$entry")

  case "$cat" in
    tmux)
      local session="${target%%:*}"
      tmux capture-pane -t "=$session" -p 2>/dev/null || echo "No preview available"
      ;;
    proj|conf|zox)
      local readme=""
      for f in "$path"/README.md "$path"/readme.md "$path"/README "$path"/README.rst; do
        [[ -f "$f" ]] && readme="$f" && break
      done
      if [[ -n "$readme" ]]; then
        bat -n --color=always --style=plain "$readme" 2>/dev/null
      else
        eza_tree "$path"
      fi
      ;;
    search)
      # Only preview files mode (target empty = files; non-empty = text/line ref)
      if [[ -z "$target" && -f "$path" ]]; then
        bat -n --color=always "$path" 2>/dev/null
      elif [[ -z "$target" && -d "$path" ]]; then
        eza_tree "$path"
      fi
      ;;
  esac
}

# ── Actions ───────────────────────────────────────────────────────────────────

open_in_editor() {
  local path="$1" line="${2:-}" dir
  if [[ -f "$path" ]]; then
    dir=$(dirname "$path")
    if [[ -n "$line" ]]; then
      tmux new-window -c "$dir" "${EDITOR:-nvim}" "+$line" "$path"
    else
      tmux new-window -c "$dir" "${EDITOR:-nvim}" "$path"
    fi
  else
    tmux new-window -c "$path" "${EDITOR:-nvim}"
  fi
}

tmux_connect() {
  local path="$1" name
  name=$(basename "$path" | sed 's/^\.//')
  tmux new-session -d -s "$name" -c "$path" 2>/dev/null
  tmux switch-client -t "=$name"
}

do_action() {
  local entry="$1" key="${2:-}"
  local cat target path
  cat=$(extract_cat "$entry")
  target=$(extract_target "$entry")
  path=$(extract_path "$entry")

  case "$cat" in
    tmux)
      local session="${target%%:*}" window="${target#*:}"
      case "$key" in
        ctrl-d) tmux kill-session -t "=$session" ;;
        *)      tmux switch-client -t "=$session"
                tmux select-window -t "${session}:${window}" ;;
      esac
      ;;
    proj|conf|zox)
      case "$key" in
        ctrl-e) open_in_editor "$path" ;;
        ctrl-v) "${VISUAL:-code}" "$path" ;;
        *)      tmux_connect "$path" ;;
      esac
      ;;
    search)
      if [[ -n "$target" ]]; then
        # Text mode: target = line number, path = file
        case "$key" in
          ctrl-v) "${VISUAL:-code}" --goto "$path:$target" ;;
          *)      open_in_editor "$path" "$target" ;;
        esac
      elif [[ -d "$path" ]]; then
        case "$key" in
          ctrl-e) open_in_editor "$path" ;;
          ctrl-v) "${VISUAL:-code}" "$path" ;;
          *)      tmux_connect "$path" ;;
        esac
      elif [[ -f "$path" ]]; then
        case "$key" in
          ctrl-v) "${VISUAL:-code}" "$path" ;;
          *)      open_in_editor "$path" ;;
        esac
      fi
      ;;
  esac
}

# ── Header ────────────────────────────────────────────────────────────────────

make_header() {
  local active="$1"
  local -a items=("All" "Sessions" "Projects" "Zoxide" "Files" "Grep")
  local -a keys=("Ctrl+A" "Ctrl+T" "Ctrl+P" "Ctrl+Z" "Ctrl+F" "Ctrl+G")
  local result="" first=1
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

# ── Subcommand dispatch ───────────────────────────────────────────────────────

case "${1:-}" in
  --source)  do_source "${2:-all}" "${3:-}"; exit ;;
  --preview) do_preview "$2"; exit ;;
esac

# ── Main ──────────────────────────────────────────────────────────────────────

trap 'rm -f /tmp/switcher-merge.* 2>/dev/null' EXIT

FOOTER_NAV="${DIM}  Connect [⏎] ◆ Editor [Ctrl+E] ◆ VS Code [Ctrl+V] ◆ Kill [Ctrl+D] ◆ Preview [Ctrl+O]${RST}"
FOOTER_TMUX="${DIM}  Switch [⏎] ◆ Kill [Ctrl+D] ◆ Preview [Ctrl+O]${RST}"
FOOTER_FSRCH="${DIM}  Open [⏎] ◆ Editor [Ctrl+E] ◆ VS Code [Ctrl+V] ◆ Preview [Ctrl+O] ◆ Text grep [Ctrl+G]${RST}"
FOOTER_GSRCH="${DIM}  Open [⏎] ◆ Editor [Ctrl+E] ◆ VS Code [Ctrl+V] ◆ Files [Ctrl+F]${RST}"

HDR_ALL=$(make_header "All")
HDR_TMUX=$(make_header "Sessions")
HDR_PROJ=$(make_header "Projects")
HDR_ZOX=$(make_header "Zoxide")
HDR_FSRCH=$(make_header "Files")
HDR_GSRCH=$(make_header "Grep")

BIND_ALL="reload($SELF --source all)+change-prompt($_ico_project  All ❯ )+change-header($HDR_ALL)+change-footer($FOOTER_NAV)"
BIND_TMUX="reload($SELF --source tmux)+change-prompt($_ico_session  Sessions ❯ )+change-header($HDR_TMUX)+change-footer($FOOTER_TMUX)"
BIND_PROJ="reload($SELF --source proj)+change-prompt($_ico_project  Projects ❯ )+change-header($HDR_PROJ)+change-footer($FOOTER_NAV)"
BIND_ZOX="reload($SELF --source zox)+change-prompt($_ico_zoxide  Zoxide ❯ )+change-header($HDR_ZOX)+change-footer($FOOTER_NAV)"
BIND_FSRCH="reload($SELF --source search files)+change-prompt($_ico_files  Files ❯ )+change-header($HDR_FSRCH)+change-footer($FOOTER_FSRCH)"
BIND_GSRCH="reload($SELF --source search text)+change-prompt($_ico_text  Grep ❯ )+change-header($HDR_GSRCH)+change-footer($FOOTER_GSRCH)+hide-preview"

result=$(source_all | fzf --tmux center,37%,60% \
  --ansi --no-info --cycle --tiebreak=begin,index \
  --delimiter $'\t' --with-nth '2..' --nth '1' \
  --border rounded --border-label ' Switcher ' --border-label-pos 3 --padding=1,2 \
  --color "$FZF_MOCHA_COLORS" \
  --header "$HDR_ALL" \
  --header-first --header-border=line \
  --prompt "$_ico_project  All ❯ " \
  --footer "$FOOTER_NAV" \
  --footer-border=line \
  --preview "$SELF --preview {}" \
  --preview-window 'bottom:30%:wrap' \
  --bind "ctrl-a:$BIND_ALL" \
  --bind "ctrl-t:$BIND_TMUX" \
  --bind "ctrl-p:$BIND_PROJ" \
  --bind "ctrl-z:$BIND_ZOX" \
  --bind "ctrl-f:$BIND_FSRCH" \
  --bind "ctrl-g:$BIND_GSRCH" \
  --bind 'ctrl-o:toggle-preview' \
  --expect 'ctrl-e,ctrl-v,ctrl-d' \
  --bind 'esc:abort')

[[ -z "$result" ]] && exit 0

key=$(head -1 <<< "$result")
entry=$(tail -1 <<< "$result")

[[ -z "$entry" ]] && exit 0

do_action "$entry" "$key"
