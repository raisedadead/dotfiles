#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2154
#
# Reader popup — three filtered views over the launch dir. fzf picks a file,
# glow renders markdown, bat renders the rest.
#
# Views (switcher-style tabs, one reload bind each):
#   Docs    (Ctrl+D, default) markdown only, .gitignore respected
#   Files   (Ctrl+F)          every file, .gitignore respected
#   Scratch (Ctrl+S)          .scratchpad/ + .claude/ only, .gitignore IGNORED
#
# The Scratch view passes --no-ignore on purpose: both directories are ignored
# in the global gitignore on this machine (~/.config/git/ignore:35 and :53), so
# a git-respecting fd finds nothing in them. Docs and Files stay git-respecting,
# and skip those trees from a repo root — with two documented exceptions. From
# INSIDE one of them git ignores the DIRECTORY, so a walk rooted at .scratchpad/
# never sees the ignored component and lists its files in Docs and Files too.
# Committing .claude/ does not surface it: fd reads ignore RULES, never the git
# index (probed — a force-added, committed .claude/agent.md is still hidden).
# Only a `!.claude` line in the repo's own .gitignore puts it back in Files.
#
# Every renderer flag below is restated on purpose. The rig's own configs are
# tuned for non-interactive use: ~/.config/bat/config sets --paging=never,
# --style=changes and --pager=delta, and both tools drop colour when stdout is
# not a tty — which is exactly what an fzf preview pane is. Inheriting either
# config here gives an uncoloured, unpaged, diff-decorated reader.

set -u

SELF="$0"
# shellcheck source=colors.sh
. "$(dirname "$0")/colors.sh"

HI="$CLR_HI"
DIM="$CLR_DIM"
ACCENT="$CLR_ACCENT"
SUB="$CLR_SUB"
RST="$CLR_RST"

# Nerd Font icons via escape sequences (the Write tool drops literal PUA chars)
_ico_doc=$'\U000F0284'     # nf-md-file_document
_ico_file=$'\U000F0219'    # nf-md-file_multiple
_ico_scratch=$'\U000F0493' # nf-md-cog

# glow exits 1 and prints nothing when an absolute style path is missing
# ("Error: specified style does not exist"), so a half-applied chezmoi state or
# a deleted file would kill the reader outright. Fall back to a built-in.
# A "~"-prefixed path behaves differently again — glow leaves it unexpanded and
# degrades quietly to unstyled output, exit 0. Neither path is worth trusting.
GLOW_STYLE="$HOME/.config/glow/mocha.json"
[[ -r "$GLOW_STYLE" ]] || GLOW_STYLE=dark

# Column count of the surrounding terminal, or 80.
# Never write `tput cols 2>/dev/null`: the redirect leaves ncurses without a
# tty fd, so it falls back to the static terminfo `cols#80` and every render
# hard-wraps at 80 no matter how wide the popup is (probed in a 160-col pane:
# `tput cols` = 160, `tput cols 2>/dev/null` = 80).
term_cols() {
  local cols
  cols="$(tput cols || true)"
  [[ "$cols" =~ ^[0-9]+$ ]] || cols=80
  printf '%s' "$cols"
}

# glow adds a 2-column margin on each side; keep the text inside the frame.
text_width() {
  local cols="$1"
  [[ "$cols" =~ ^[0-9]+$ ]] || cols=80
  ((cols > 24)) && printf '%s' "$((cols - 4))" || printf '20'
}

is_markdown() {
  case "${1,,}" in
    *.md | *.markdown | *.mdown | *.mkd | *.mkdn | *.mdwn | *.mdtext | *.mdx)
      return 0
      ;;
  esac
  return 1
}

# ── Sources ───────────────────────────────────────────────────────────────────
#
# fd respects .gitignore in the Docs and Files views (no --no-ignore-vcs,
# unlike FD_COMMON_OPTS in fzf.zsh): build output and vendored trees are noise
# in a reader.
#
# Every source is NUL-delimited end to end, because a filename may contain a
# newline: on newlines `bad<LF>name.txt` reaches fzf as two rows, neither of
# which exists.
FD_TREE=(--hidden --follow --exclude .git --exclude node_modules --exclude .venv)
MD_EXT=(-e md -e markdown -e mdown -e mkd -e mkdn -e mdwn -e mdtext -e mdx)

# fd applies gitignore rules ONLY inside a repository, and #{pane_current_path}
# is often outside one (~, ~/Downloads, /tmp) — there, Docs and Files would list
# .claude/ and .scratchpad/, the Scratch tab's whole content leaked into both.
# The fix holds the tab contract by name, NOT with fd's --no-require-git: that
# flag applies the entire global ignore file off-repo, and ~/.config/git/ignore
# lists CLAUDE.md (:38), AGENTS.md (:42) and .env (:57) — a markdown reader that
# hides CLAUDE.md outside a repo trades one leak for a worse one.
# Inside a repo nothing is added, so a repo that re-includes .claude with its own
# `!.claude` line still shows it in Files.
view_opts() {
  VIEW_OPTS=("${FD_TREE[@]}")
  git rev-parse --is-inside-work-tree > /dev/null 2>&1 ||
    VIEW_OPTS+=(--exclude .claude --exclude .scratchpad)
}

# Row format, NUL-terminated: <display><TAB><path>
# The path is LAST and the display half has every tab and newline replaced with
# a space, so the first tab in a row is always the field separator: a filename
# containing a tab used to leave `${row#*\t}` holding a fragment, and both the
# preview and the pager then opened nothing.
#
# The display is the whole relative path — dim directory, bright basename — not
# a padded name column. A padded column broke path-ordered queries: fzf matches
# against the --with-nth text only, so `tmux/scripts/read` found nothing once
# the directory moved behind the name (probed with --filter).
render_rows() {
  local p name dir icon
  while IFS= read -r -d '' p; do
    p="${p#./}"
    name="${p##*/}"
    dir="${p%/*}"
    if [[ "$dir" == "$p" ]]; then dir=""; else dir="$dir/"; fi
    if is_markdown "$p"; then icon="$_ico_doc"; else icon="$_ico_file"; fi
    name="${name//$'\t'/ }"; name="${name//$'\n'/ }"
    dir="${dir//$'\t'/ }"; dir="${dir//$'\n'/ }"
    printf '%s%s  %s%s%s%s%s\t%s\0' \
      "$SUB" "$icon" "$DIM" "$dir" "$HI" "$name" "$RST" "$p"
  done
}

source_docs() {
  local -a VIEW_OPTS
  view_opts
  fd -0 --type f "${VIEW_OPTS[@]}" "${MD_EXT[@]}" | render_rows
}

source_files() {
  local -a VIEW_OPTS
  view_opts
  fd -0 --type f "${VIEW_OPTS[@]}" | render_rows
}

# Directory discovery is depth-capped at 4 and prunes the macOS bulk on purpose:
# --no-ignore walks trees that .gitignore normally prunes, and an uncapped walk
# from $HOME crawls ~/Library. Measured from $HOME, 48 roots either way: the cap
# alone runs ~0.3 s but spikes past 6 s on a cold slice (seen twice), while the
# three excludes hold 0.19 s across runs. Depth 3 is faster still and finds 11
# of the 48 — too few; these directories sit at repo roots, and a repo is
# commonly ~/dev/<org>/<repo>, which is depth 4.
# Each exclude is anchored with a leading slash, which pins it to the walk root:
# a bare `Library` matches every component, so a project holding Library/.claude
# would vanish from the tab (probed). The excludes are on the discovery walk
# only, never on FD_TREE, so Docs and Files list whatever is under the launch
# dir.
# When the popup opens from inside one of the two directories, the regex finds no
# child match, so take the cwd itself as the root — otherwise the tab would be
# empty exactly where it is most useful.
#
# Roots are passed as --search-path=<path>, never as bare positionals: fd parses
# a positional beginning with "-" as an option, and `. -dash/.claude` dies with
# `invalid value 'ash/.claude' for '--max-depth'`, taking the whole tab with it.
source_scratch() {
  local -a roots=()
  local d
  case "$PWD/" in
    */.scratchpad/* | */.claude/*) roots=(--search-path=.) ;;
    *)
      while IFS= read -r -d '' d; do roots+=("--search-path=$d"); done < <(
        fd -0 --type d --max-depth 4 --no-ignore "${FD_TREE[@]}" \
          --exclude /Library --exclude /.Trash --exclude /.cache \
          '^\.(scratchpad|claude)$'
      )
      ;;
  esac
  ((${#roots[@]})) || return 0
  fd -0 --type f --no-ignore "${FD_TREE[@]}" "${roots[@]}" . | render_rows
}

do_source() {
  case "${1:-docs}" in
    docs) source_docs ;;
    files) source_files ;;
    scratch) source_scratch ;;
    *)
      echo "Unknown view: $1" >&2
      exit 1
      ;;
  esac
}

# ── Preview ───────────────────────────────────────────────────────────────────

# fzf preview pane. Colour and width are forced because stdout is a pipe.
preview() {
  local file="$1" width
  width="$(text_width "${FZF_PREVIEW_COLUMNS:-80}")"
  if is_markdown "$file"; then
    glow -s "$GLOW_STYLE" -w "$width" -- "$file"
  else
    bat --color=always --style=numbers --paging=never \
      --terminal-width="$width" --wrap=auto -- "$file"
  fi
}

# {} hands the preview the ORIGINAL row, not the --with-nth display half
# (probed on fzf 0.74.3), so the path is still there to cut out.
preview_row() {
  local file="${1#*$'\t'}"
  [[ -f "$file" ]] || exit 0
  preview "$file"
}

# ── Header ────────────────────────────────────────────────────────────────────

# Labels are terse for one reason: the header and the footer span the LIST
# column only, not the popup, and --keep-right truncates both from the LEFT —
# the long form lost `Ctrl+D Docs`, the active tab on open, at 100 columns
# (probed: `··cs · Ctrl+F Files · Ctrl+S Scratch`). The short form fits there.
make_header() {
  local active="$1"
  local -a items=("Docs" "Files" "Scratch")
  local -a keys=("^D" "^F" "^S")
  local result="" first=1 i
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
  --preview)
    preview_row "${2:-}"
    exit 0
    ;;
  --source)
    do_source "${2:-docs}"
    exit 0
    ;;
esac

# ── Main ──────────────────────────────────────────────────────────────────────

HDR_DOCS=$(make_header "Docs")
HDR_FILES=$(make_header "Files")
HDR_SCRATCH=$(make_header "Scratch")

FOOTER="${DIM}⏎ read · ^/ preview · esc quit${RST}"

BIND_DOCS="reload('$SELF' --source docs)+change-prompt($_ico_doc  Docs ❯ )+change-header($HDR_DOCS)"
BIND_FILES="reload('$SELF' --source files)+change-prompt($_ico_file  Files ❯ )+change-header($HDR_FILES)"
BIND_SCRATCH="reload('$SELF' --source scratch)+change-prompt($_ico_scratch  Scratch ❯ )+change-header($HDR_SCRATCH)"

# --height=100% and --keep-right are both stated, never inherited. The tmux
# server environment carries FZF_DEFAULT_OPTS from fzf.zsh, so a popup silently
# picks up every option in it — --height=60% draws fzf in the top 60% of the
# popup with dead space below. Command-line options win, so state what this
# reader depends on. --keep-right is what the path display wants: an
# overflowing row loses its leading directories, never its filename.
# Checked: an unchecked mktemp leaves sel_file empty, the redirect below fails,
# fzf never runs and the script falls through to exit 0 — which -EE reads as
# success and closes the popup over the error message.
sel_file="$(mktemp "${TMPDIR:-/tmp}/read-popup.XXXXXX")" || {
  echo "read-popup: cannot create a temporary file" >&2
  exit 1
}
trap 'rm -f "$sel_file"' EXIT

source_docs | fzf --read0 --print0 --ansi --height=100% --keep-right \
  --layout=reverse --border=rounded --info=right \
  --pointer='▶' --marker='●' --separator='─' --scrollbar='│' \
  --delimiter=$'\t' --with-nth 1 \
  --color="$FZF_MOCHA_COLORS" \
  --prompt="$_ico_doc  Docs ❯ " \
  --header "$HDR_DOCS" --header-first --header-border=line \
  --footer "$FOOTER" --footer-border=line \
  --preview "'$SELF' --preview {}" \
  --preview-window='border-rounded:right:60%' \
  --bind "ctrl-d:$BIND_DOCS" \
  --bind "ctrl-f:$BIND_FILES" \
  --bind "ctrl-s:$BIND_SCRATCH" \
  --bind 'ctrl-/:toggle-preview' \
  --bind 'shift-up:preview-half-page-up' \
  --bind 'shift-down:preview-half-page-down' \
  --bind 'esc:abort' >"$sel_file"

# --print0 keeps a newline inside a filename intact; read the single NUL record
# from a file rather than a process substitution so fzf has fully released the
# tty before the pager starts.
sel=""
IFS= read -r -d '' sel <"$sel_file" || true
rm -f "$sel_file"

file="${sel#*$'\t'}"
[[ -n "$file" && -f "$file" ]] || exit 0

width="$(text_width "$(term_cols)")"

if is_markdown "$file"; then
  # glow.yml sets pager: true, so glow pages itself.
  exec glow -s "$GLOW_STYLE" -w "$width" -- "$file"
fi

# less, not the configured delta: delta decorates diffs, not plain files.
exec bat --color=always --style=numbers,header --paging=always \
  --pager='less -R' --terminal-width="$width" --wrap=auto -- "$file"
