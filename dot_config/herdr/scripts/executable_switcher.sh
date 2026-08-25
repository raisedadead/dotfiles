#!/usr/bin/env bash
# shellcheck disable=SC2155

set -u

SELF="$0"

command -v jq >/dev/null 2>&1 ||
  { printf 'switcher: jq is required\n' >&2; exit 1; }

DIM=$'\033[38;2;147;153;178m'
HI=$'\033[38;2;137;180;250m'
ACCENT=$'\033[38;2;249;226;175m'
SUB=$'\033[38;2;166;173;200m'
GREEN=$'\033[38;2;166;227;161m'
MAUVE=$'\033[38;2;203;166;247m'
RST=$'\033[0m'

FZF_MOCHA_COLORS="bg+:#313244,bg:#11111B,spinner:#F5E0DC,hl:#F38BA8"
FZF_MOCHA_COLORS+=",fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC"
FZF_MOCHA_COLORS+=",marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8"
FZF_MOCHA_COLORS+=",selected-bg:#45475A,border:#6C7086,label:#CDD6F4"

_ico_space=$'\U000F018D'
_ico_project=$'\U000F0770'
_ico_config=$'\U000F0493'
_ico_zoxide=$'\U000F02DA'
_ico_files=$'\U000F0219'
_ico_text=$'\U000F0284'
_ico_bookmark=$'\U000F00C0'

HERDR="${HERDR_BIN_PATH:-herdr}"
PROJECTS_JSON="$HOME/.config/switcher/projects.json"
BOOKMARKS_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/switcher/bookmarks"
TAB_FILE="${SWITCHER_TAB_FILE:-}"
BASE_DIR="${HERDR_ACTIVE_PANE_CWD:-$HOME}"

expand_tilde() { echo "${1/#\~/$HOME}"; }
shorten()      { echo "${1/#$HOME/\~}"; }

bookmarks_raw() { [[ -f "$BOOKMARKS_FILE" ]] && cat "$BOOKMARKS_FILE"; return 0; }

_BM_SET=$'\n'"$(bookmarks_raw)"$'\n'
is_bookmarked() { [[ -n "$1" && "$_BM_SET" == *$'\n'"$1"$'\n'* ]]; }

toggle_bookmark() {
  local path="${1%/}" tmp
  [[ -n "$path" && -d "$path" ]] || return 1
  mkdir -p "${BOOKMARKS_FILE%/*}"
  if is_bookmarked "$path"; then
    tmp=$(mktemp "${BOOKMARKS_FILE}.XXXXXX")
    grep -vxF -- "$path" "$BOOKMARKS_FILE" > "$tmp" 2>/dev/null
    mv "$tmp" "$BOOKMARKS_FILE"
  else
    printf '%s\n' "$path" >> "$BOOKMARKS_FILE"
  fi
}

render_line() {
  local cat="$1" target="$2" path="$3"
  local name short icon cat_label cat_color mark
  short=$(shorten "$path")
  case "$cat" in
    space) name="${target#*:}"; icon="$_ico_space";   cat_label="space";   cat_color="$GREEN" ;;
    proj)  name=$(basename "$path"); icon="$_ico_project"; cat_label="project"; cat_color="$HI" ;;
    conf)  name=$(basename "$path"); icon="$_ico_config";  cat_label="config";  cat_color="$ACCENT" ;;
    zox)   name=$(basename "$path"); icon="$_ico_zoxide";  cat_label="zoxide";  cat_color="$MAUVE" ;;
    *) return ;;
  esac
  if is_bookmarked "$path"; then mark="${ACCENT}${_ico_bookmark}${RST}  "; else mark="   "; fi
  printf '%s|%s|%s\t%s%s%s  %-20s%s\t%s%-7s%s\t%s%s%s\n' \
    "$cat" "$target" "$path" \
    "$mark" "$HI" "$icon" "$name" "$RST" \
    "$cat_color" "$cat_label" "$RST" \
    "$DIM" "$short" "$RST"
}

render_all() {
  while IFS='|' read -r _score cat target path; do
    render_line "$cat" "$target" "$path"
  done
}

_spaces_raw() {
  local spaces panes
  spaces=$("$HERDR" workspace list 2>/dev/null) || return 0
  panes=$("$HERDR" pane list 2>/dev/null) || panes='{}'
  jq -rn --argjson w "$spaces" --argjson p "$panes" --arg home "$HOME" '
    ($p.result.panes // [])
    | group_by(.workspace_id)
    | map({key: .[0].workspace_id,
           value: ((map(select(.focused)) | first) // .[0]).cwd})
    | from_entries as $cwd
    | ($w.result.workspaces // [])[]
    | . as $s
    | (if $s.focused then 108000
       elif $s.agent_status == "blocked" then 107000
       elif $s.agent_status == "done"    then 106000
       elif $s.agent_status == "working" then 105000
       else 104000 end) as $base
    | ($base * 1000 - ($s.number // 999)) as $score
    | (($s.label // "") | gsub("[|\\t]"; " ")) as $label
    | "\($score)|1|space|\($s.workspace_id):\($label)|\($cwd[$s.workspace_id] // $home)"
  ' 2>/dev/null
}

_source_all_raw() {
  local tmpfile
  tmpfile=$(mktemp /tmp/herdr-switcher-merge.XXXXXX)

  {
    zoxide query --list --score 2>/dev/null | while read -r score path; do
      [[ -d "$path" ]] || continue
      printf '%s|4|zox||%s\n' "$score" "$path"
    done

    local dirs=()
    if [[ -f "$PROJECTS_JSON" ]]; then
      while IFS= read -r d; do
        d=$(expand_tilde "$d"); [[ -d "$d" ]] && dirs+=("$d")
      done < <(jq -r '.configDirs[]? // empty' "$PROJECTS_JSON" 2>/dev/null)
    fi
    [[ ${#dirs[@]} -eq 0 ]] && dirs=(
      "$HOME/.config/nvim" "$HOME/.config/herdr"
      "$HOME/.config/ghostty" "$HOME/.dotfiles"
    )
    for d in "${dirs[@]}"; do
      [[ -d "$d" ]] && printf '50|3|conf||%s\n' "$d"
    done

    while IFS= read -r bm; do
      bm="${bm%/}"; [[ -n "$bm" && -d "$bm" ]] && printf '200|2|proj||%s\n' "$bm"
    done < <(bookmarks_raw)

    if [[ -f "$PROJECTS_JSON" ]]; then
      while IFS='|' read -r _scope base; do
        base=$(expand_tilde "$base"); [[ -d "$base" ]] || continue
        if command -v fd >/dev/null 2>&1; then
          fd -d 1 -t d . "$base" 2>/dev/null
        else
          find "$base" -maxdepth 1 -mindepth 1 -type d 2>/dev/null
        fi | while IFS= read -r p; do
          p="${p%/}"; [[ -d "$p" ]] && printf '100|2|proj||%s\n' "$p"
        done
      done < <(jq -r '.baseFolders[]? | "\(.scope // "Other")|\(.path)"' "$PROJECTS_JSON" 2>/dev/null)

      while IFS= read -r fav; do
        fav=$(expand_tilde "$fav"); fav="${fav%/}"
        [[ -n "$fav" && -d "$fav" ]] && printf '200|2|proj||%s\n' "$fav"
      done < <(jq -r '.favorites[]? | select(.enabled != false) | .rootPath // empty' "$PROJECTS_JSON" 2>/dev/null)
    fi

    _spaces_raw
  } >> "$tmpfile"

  sort -t'|' -k5,5 -k2,2n "$tmpfile" | awk -F'|' '
  function flush(   i) {
    if (last_path == "") return
    if (nsp > 0) {
      for (i = 1; i <= nsp; i++)
        printf "%s|space|%s|%s\n", sp_score[i], sp_target[i], last_path
      return
    }
    printf "%s|%s|%s|%s\n", best_score, best_cat, best_target, last_path
  }
  {
    score=$1+0; cat=$3; target=$4; path=$5
    if (path != last_path) {
      flush()
      last_path=path; best_score=score; best_cat=cat; best_target=target; nsp=0
    } else if (score > best_score) best_score=score
    if (cat == "space") { nsp++; sp_score[nsp]=score; sp_target[nsp]=target }
  }
  END { flush() }
  ' | sort -t'|' -k1,1 -rn

  rm -f "$tmpfile"
}

source_all() { _source_all_raw | render_all; }

source_spaces() {
  _spaces_raw | sort -t'|' -k1,1 -rn | while IFS='|' read -r _score _prio cat target path; do
    render_line "$cat" "$target" "$path"
  done
}

source_proj() {
  local paths=() seen=$'\n' p

  while IFS= read -r bm; do
    bm="${bm%/}"; [[ -n "$bm" && -d "$bm" ]] || continue
    [[ "$seen" == *$'\n'"$bm"$'\n'* ]] && continue
    seen+="$bm"$'\n'
    render_line "proj" "" "$bm"
  done < <(bookmarks_raw)

  [[ -f "$PROJECTS_JSON" ]] || return 0

  while IFS= read -r fav; do
    fav=$(expand_tilde "$fav"); fav="${fav%/}"
    [[ -n "$fav" && -d "$fav" ]] || continue
    [[ "$seen" == *$'\n'"$fav"$'\n'* ]] && continue
    seen+="$fav"$'\n'
    render_line "proj" "" "$fav"
  done < <(jq -r '.favorites[]? | select(.enabled != false) | .rootPath // empty' "$PROJECTS_JSON" 2>/dev/null)

  while IFS='|' read -r _scope base; do
    base=$(expand_tilde "$base"); [[ -d "$base" ]] || continue
    if command -v fd >/dev/null 2>&1; then
      while IFS= read -r p; do p="${p%/}"; [[ -d "$p" ]] && paths+=("$p"); done \
        < <(fd -d 1 -t d . "$base" 2>/dev/null | sort)
    else
      while IFS= read -r p; do p="${p%/}"; [[ -d "$p" ]] && paths+=("$p"); done \
        < <(find "$base" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)
    fi
  done < <(jq -r '.baseFolders[]? | "\(.scope // "Other")|\(.path)"' "$PROJECTS_JSON" 2>/dev/null)

  for p in "${paths[@]}"; do
    [[ "$seen" == *$'\n'"$p"$'\n'* ]] && continue
    seen+="$p"$'\n'
    render_line "proj" "" "$p"
  done
}

source_conf() {
  local dirs=()
  if [[ -f "$PROJECTS_JSON" ]]; then
    while IFS= read -r d; do
      d=$(expand_tilde "$d"); [[ -d "$d" ]] && dirs+=("$d")
    done < <(jq -r '.configDirs[]? // empty' "$PROJECTS_JSON" 2>/dev/null)
  fi
  [[ ${#dirs[@]} -eq 0 ]] && dirs=(
    "$HOME/.config/nvim" "$HOME/.config/herdr"
    "$HOME/.config/ghostty" "$HOME/.dotfiles"
  )
  for d in "${dirs[@]}"; do [[ -d "$d" ]] && render_line "conf" "" "$d"; done
}

source_zox() {
  zoxide query --list --score 2>/dev/null | while read -r _score path; do
    [[ -d "$path" ]] && render_line "zox" "" "$path"
  done
}

source_search() {
  local mode="${1:-files}"

  if [[ "$mode" == "text" ]]; then
    rg --no-heading --line-number --color=always . "$BASE_DIR" 2>/dev/null | head -5000 |
      SW_HI="$HI" SW_ICO="$_ico_text" perl -ne '
        chomp;
        my $raw = $_;
        (my $clean = $raw) =~ s/\e\[[0-9;]*m//g;
        my ($file, $lineno) = split(/:/, $clean, 3);
        next unless defined $lineno;
        print "search|$lineno|$file\t$ENV{SW_HI}$ENV{SW_ICO}  $raw\n";
      '
  else
    fd --max-depth 4 --type f --type d . "$BASE_DIR" 2>/dev/null | head -5000 |
      SW_HI="$HI" SW_DIM="$DIM" SW_ACCENT="$ACCENT" SW_RST="$RST" \
      SW_ICO="$_ico_files" SW_MARK="$_ico_bookmark" SW_HOME="$HOME" \
      SW_BM="$BOOKMARKS_FILE" perl -ne '
        BEGIN {
          %bm = ();
          if (open my $fh, "<", $ENV{SW_BM}) {
            while (<$fh>) { chomp; s{/+$}{}; $bm{$_} = 1 if length }
            close $fh;
          }
        }
        chomp;
        s{/+$}{};
        next unless length;
        my $short = $_;
        $short =~ s/^\Q$ENV{SW_HOME}\E/~/;
        my ($name) = m{([^/]+)$};
        $name = $_ unless defined $name;
        my $mark = $bm{$_} ? "$ENV{SW_ACCENT}$ENV{SW_MARK}$ENV{SW_RST}  " : "   ";
        printf "search||%s\t%s%s%s  %-22s%s\t%ssrch%s\t%s%s%s\n",
          $_, $mark, $ENV{SW_HI}, $ENV{SW_ICO}, $name, $ENV{SW_RST},
          $ENV{SW_DIM}, $ENV{SW_RST}, $ENV{SW_DIM}, $short, $ENV{SW_RST};
      '
  fi
}

do_source() {
  [[ -n "$TAB_FILE" ]] && printf '%s %s\n' "$1" "${2:-}" > "$TAB_FILE"
  case "$1" in
    all)    source_all ;;
    spaces) source_spaces ;;
    proj)   source_proj ;;
    conf)   source_conf ;;
    zox)    source_zox ;;
    search) source_search "${2:-files}" ;;
    *)      echo "Unknown source: $1" >&2; exit 1 ;;
  esac
}

_internal()      { cut -f1 <<< "$1"; }
extract_cat()    { _internal "$1" | cut -d'|' -f1; }
extract_target() { _internal "$1" | cut -d'|' -f2; }
extract_path()   { _internal "$1" | cut -d'|' -f3; }

eza_tree() {
  eza --tree --level=2 --icons --color=always --group-directories-first \
    --ignore-glob='node_modules|.git|__pycache__|.next|dist|build|.cache|.turbo|vendor' \
    "$1" 2>/dev/null || ls -la "$1" 2>/dev/null
}

_space_pane() {
  "$HERDR" pane list --workspace "$1" 2>/dev/null |
    jq -r '(.result.panes // []) | ((map(select(.focused)) | first) // .[0]) | .pane_id // empty'
}

do_preview() {
  local entry="$1"
  local cat target path
  cat=$(extract_cat "$entry")
  target=$(extract_target "$entry")
  path=$(extract_path "$entry")

  case "$cat" in
    space)
      local pane
      pane=$(_space_pane "${target%%:*}")
      if [[ -n "$pane" ]]; then
        "$HERDR" pane read "$pane" --source visible --format ansi 2>/dev/null ||
          echo "No preview available"
      else
        echo "No preview available"
      fi
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
      if [[ -z "$target" && -f "$path" ]]; then
        bat -n --color=always "$path" 2>/dev/null
      elif [[ -z "$target" && -d "$path" ]]; then
        eza_tree "$path"
      fi
      ;;
  esac
}

_editor_cmd() {
  local -a words=()
  read -r -a words <<< "${EDITOR:-nvim}"
  [[ ${#words[@]} -gt 0 ]] || words=(nvim)
  local out="" w
  for w in "${words[@]}" "$@"; do
    out+="$(printf '%q' "$w") "
  done
  printf '%s' "${out% }"
}

open_in_editor() {
  local path="$1" line="${2:-}" ws="${3:-}" dir out pane cmd
  local -a create=(tab create --focus)
  if [[ -f "$path" ]]; then dir=$(dirname "$path"); else dir="$path"; fi
  [[ -n "$ws" ]] && create+=(--workspace "$ws")
  create+=(--cwd "$dir" --label "$(basename "$dir")")
  out=$("$HERDR" "${create[@]}" 2>/dev/null) || return 1
  pane=$(jq -r '.result.root_pane.pane_id // empty' <<< "$out")
  [[ -n "$pane" ]] || return 1
  if [[ -f "$path" && "$line" =~ ^[0-9]+$ ]]; then
    cmd=$(_editor_cmd "+$line" "$path")
  elif [[ -f "$path" ]]; then
    cmd=$(_editor_cmd "$path")
  else
    cmd=$(_editor_cmd)
  fi
  "$HERDR" pane run "$pane" "$cmd" >/dev/null 2>&1
}

space_connect() {
  local path="${1%/}" existing label
  existing=$("$HERDR" pane list 2>/dev/null |
    jq -r --arg p "$path" '(.result.panes // [])[] | select(.cwd == $p) | .workspace_id' |
    head -1)
  if [[ -n "$existing" ]]; then
    "$HERDR" workspace focus "$existing" >/dev/null 2>&1
    return
  fi
  label=$(basename "$path"); label="${label#.}"
  "$HERDR" workspace create --cwd "$path" --label "$label" --focus >/dev/null 2>&1
}

do_action() {
  local entry="$1" key="${2:-}"
  local cat target path
  cat=$(extract_cat "$entry")
  target=$(extract_target "$entry")
  path=$(extract_path "$entry")

  case "$cat" in
    space)
      local id="${target%%:*}"
      case "$key" in
        ctrl-d) "$HERDR" workspace close "$id" >/dev/null 2>&1 ;;
        ctrl-e) open_in_editor "$path" "" "$id" ;;
        ctrl-v) "${VISUAL:-code}" "$path" ;;
        *)      "$HERDR" workspace focus "$id" >/dev/null 2>&1 ;;
      esac
      ;;
    proj|conf|zox)
      case "$key" in
        ctrl-e) open_in_editor "$path" ;;
        ctrl-v) "${VISUAL:-code}" "$path" ;;
        *)      space_connect "$path" ;;
      esac
      ;;
    search)
      if [[ -n "$target" ]]; then
        case "$key" in
          ctrl-v) "${VISUAL:-code}" --goto "$path:$target" ;;
          *)      open_in_editor "$path" "$target" ;;
        esac
      elif [[ -d "$path" ]]; then
        case "$key" in
          ctrl-e) open_in_editor "$path" ;;
          ctrl-v) "${VISUAL:-code}" "$path" ;;
          *)      space_connect "$path" ;;
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

make_header() {
  local active="$1"
  local -a items=("All" "Spaces" "Projects" "Zoxide" "Files" "Grep")
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

case "${1:-}" in
  --source)   do_source "${2:-all}" "${3:-}"; exit ;;
  --preview)  do_preview "$2"; exit ;;
  --bookmark)
    toggle_bookmark "$(extract_path "$2")" &&
      printf 'reload(%s --source-current)' "$SELF"
    exit 0 ;;
  --source-current)
    if [[ -n "$TAB_FILE" && -s "$TAB_FILE" ]]; then
      read -r _tab _arg < "$TAB_FILE"
      do_source "${_tab:-all}" "${_arg:-}"
    else
      do_source all
    fi
    exit ;;
esac

SWITCHER_TAB_FILE=$(mktemp /tmp/herdr-switcher-tab.XXXXXX)
export SWITCHER_TAB_FILE
TAB_FILE="$SWITCHER_TAB_FILE"
trap 'rm -f "$SWITCHER_TAB_FILE"' EXIT
printf 'all \n' > "$TAB_FILE"

FOOTER_NAV="${DIM}  Connect [⏎] ◆ Bookmark [Ctrl+S] ◆ Editor [Ctrl+E] ◆ VS Code [Ctrl+V] ◆ Close [Ctrl+D] ◆ Preview [Ctrl+/]${RST}"
FOOTER_SPACE="${DIM}  Focus [⏎] ◆ Bookmark [Ctrl+S] ◆ Close [Ctrl+D] ◆ Preview [Ctrl+/]${RST}"
FOOTER_FSRCH="${DIM}  Open [⏎] ◆ Editor [Ctrl+E] ◆ VS Code [Ctrl+V] ◆ Preview [Ctrl+/] ◆ Text grep [Ctrl+G]${RST}"
FOOTER_GSRCH="${DIM}  Open [⏎] ◆ Editor [Ctrl+E] ◆ VS Code [Ctrl+V] ◆ Files [Ctrl+F]${RST}"

HDR_ALL=$(make_header "All")
HDR_SPACE=$(make_header "Spaces")
HDR_PROJ=$(make_header "Projects")
HDR_ZOX=$(make_header "Zoxide")
HDR_FSRCH=$(make_header "Files")
HDR_GSRCH=$(make_header "Grep")

BIND_ALL="reload($SELF --source all)+change-prompt($_ico_project  All ❯ )+change-header($HDR_ALL)+change-footer($FOOTER_NAV)"
BIND_SPACE="reload($SELF --source spaces)+change-prompt($_ico_space  Spaces ❯ )+change-header($HDR_SPACE)+change-footer($FOOTER_SPACE)"
BIND_PROJ="reload($SELF --source proj)+change-prompt($_ico_project  Projects ❯ )+change-header($HDR_PROJ)+change-footer($FOOTER_NAV)"
BIND_ZOX="reload($SELF --source zox)+change-prompt($_ico_zoxide  Zoxide ❯ )+change-header($HDR_ZOX)+change-footer($FOOTER_NAV)"
BIND_FSRCH="reload($SELF --source search files)+change-prompt($_ico_files  Files ❯ )+change-header($HDR_FSRCH)+change-footer($FOOTER_FSRCH)"
BIND_MARK="transform($SELF --bookmark {})"
BIND_GSRCH="reload($SELF --source search text)+change-prompt($_ico_text  Grep ❯ )+change-header($HDR_GSRCH)+change-footer($FOOTER_GSRCH)+hide-preview"

result=$(source_all | fzf --height="${SWITCHER_HEIGHT:-100%}" \
  --ansi --no-info --cycle --tiebreak=begin,index --no-keep-right \
  --delimiter $'\t' --with-nth '2..' --nth '1' \
  --border rounded --border-label ' Switcher ' --border-label-pos 3 --padding=1,2 \
  --color "$FZF_MOCHA_COLORS" \
  --header "$HDR_ALL" \
  --header-first --header-border=line \
  --prompt "$_ico_project  All ❯ " \
  --footer "$FOOTER_NAV" \
  --footer-border=line \
  --preview "$SELF --preview {}" \
  --preview-window 'bottom:30%:wrap:hidden' \
  --bind "ctrl-a:$BIND_ALL" \
  --bind "ctrl-t:$BIND_SPACE" \
  --bind "ctrl-p:$BIND_PROJ" \
  --bind "ctrl-z:$BIND_ZOX" \
  --bind "ctrl-f:$BIND_FSRCH" \
  --bind "ctrl-g:$BIND_GSRCH" \
  --bind "ctrl-s:$BIND_MARK" \
  --bind 'ctrl-/:toggle-preview' \
  --bind 'ctrl-o:toggle-preview' \
  --expect 'ctrl-e,ctrl-v,ctrl-d' \
  --bind 'esc:abort')

[[ -z "$result" ]] && exit 0

key=$(head -1 <<< "$result")
entry=$(tail -1 <<< "$result")

[[ -z "$entry" ]] && exit 0

do_action "$entry" "$key"
