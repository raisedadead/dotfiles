#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2154
#
# Reader popup — fzf picks a file, glow renders markdown, bat renders the rest.
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

if [[ "${1:-}" == "--preview" ]]; then
  preview "${2:-}"
  exit 0
fi

# fd respects .gitignore here (no --no-ignore-vcs, unlike FD_COMMON_OPTS in
# fzf.zsh): build output and vendored trees are noise in a reader.
#
# NUL-delimited, because a filename may contain a newline: on newlines
# `bad<LF>name.txt` reaches fzf as two rows, neither of which exists.
#
# --height=100% is load-bearing. The tmux server environment carries
# FZF_DEFAULT_OPTS from fzf.zsh, --height=60% and all, so a popup inherits it
# and fzf draws in the top 60% with dead space below. Command-line options win
# over FZF_DEFAULT_OPTS, so restating it here reclaims the whole popup.
file="$(
  fd -0 --type f --hidden --follow \
    --exclude .git --exclude node_modules --exclude .venv |
    fzf --read0 --ansi --height=100% --layout=reverse --border=rounded \
      --info=right --prompt='❯ ' --pointer='▶' --marker='●' \
      --separator='─' --scrollbar='│' \
      --color="$FZF_MOCHA_COLORS" \
      --preview "'$SELF' --preview {}" \
      --preview-window='border-rounded:right:60%' \
      --bind 'ctrl-/:toggle-preview' \
      --bind 'shift-up:preview-half-page-up' \
      --bind 'shift-down:preview-half-page-down' \
      --header 'Enter read  ·  Ctrl-/ preview  ·  Esc cancel'
)" || exit 0

[[ -n "$file" ]] || exit 0

width="$(text_width "$(term_cols)")"

if is_markdown "$file"; then
  # glow.yml sets pager: true, so glow pages itself.
  exec glow -s "$GLOW_STYLE" -w "$width" -- "$file"
fi

# less, not the configured delta: delta decorates diffs, not plain files.
exec bat --color=always --style=numbers,header --paging=always \
  --pager='less -R' --terminal-width="$width" --wrap=auto -- "$file"
