#-----------------------------------------------------------
# @raisedadead's config files
# Copyright: Mrugesh Mohapatra <https://mrugesh.dev>
# License: ISC
#
# File name: .zshrc
#-----------------------------------------------------------

# Performance profiling (set ZPROF=true to enable)
[[ "$ZPROF" = true ]] && zmodload zsh/zprof

#-----------------------------------------------------------
# Core Settings
#-----------------------------------------------------------
umask 022
limit coredumpsize 0

# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt INC_APPEND_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS

# Options
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt CDABLE_VARS
setopt INTERACTIVECOMMENTS

# Helpers
can_haz() { whence -p "$1" >/dev/null 2>&1 }
timezsh() { for i in {1..10}; do time zsh -i -c exit; done }

# Cache and source tool-generated shell code (regenerates when binary updates)
# Usage: cached_evalz <tool> "<command>"
cached_evalz() {
  local tool=$1 cmd=$2 cache_dir="$HOME/.cache/zsh-eval-cache"
  can_haz "$tool" || return 1
  local bin="$(whence -p "$tool")" cache="$cache_dir/$tool.zsh"
  [[ -d "$cache_dir" ]] || mkdir -p "$cache_dir"
  if [[ ! -f "$cache" ]] || [[ "$bin" -nt "$cache" ]]; then
    eval "$cmd" > "$cache" 2>/dev/null && zcompile "$cache" 2>/dev/null
  fi
  source "$cache"
}

# Keybindings
bindkey -e  # Emacs mode
bindkey -M viins 'jk' vi-cmd-mode
bindkey '^[f' forward-word          # Alt+F / Opt+Right: forward word (accepts suggestion word-by-word)
bindkey '^[b' backward-word         # Alt+B / Opt+Left: backward word
bindkey '^[[1;3C' forward-word      # Opt+Right arrow
bindkey '^[[1;3D' backward-word     # Opt+Left arrow
bindkey '\eh' backward-word         # Alt+H: back one word
bindkey '\el' forward-word          # Alt+L: forward one word (accepts suggestion word-by-word)
bindkey '\ej' down-line-or-history  # Alt+J: next history
bindkey '\ek' up-line-or-history    # Alt+K: prev history

# Prompt
# can_haz starship && eval "$(starship init zsh)"
cached_evalz oh-my-posh "oh-my-posh init zsh --config ~/.config/oh-my-posh/config.toml"

#-----------------------------------------------------------
# Plugin Manager
#-----------------------------------------------------------
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[[ ! -d $ZINIT_HOME ]] && mkdir -p "$(dirname $ZINIT_HOME)" && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "$ZINIT_HOME/zinit.zsh"
#-----------------------------------------------------------

# Load zsh-defer first
zinit light romkatv/zsh-defer

# FZF - core setup (DO NOT DEFER, need immediate availability)
source ~/.fzf.zsh
# FZF styling (can be deferred)
zsh-defer source ~/.fzf.zshrc

# Compile zinit and plugins (once daily via stamp file)
zsh-defer -c '
  local stamp="$HOME/.cache/zinit-compile-stamp"
  if [[ ! -f "$stamp" ]] || [[ $(( $(date +%s) - $(stat -f%m "$stamp" 2>/dev/null || echo 0) )) -gt 86400 ]]; then
    zinit compile --all 2>/dev/null
    touch "$stamp"
  fi
'

# Load completions before compinit (per zsh-completions guidelines)
zinit light zsh-users/zsh-completions
zinit light wbingli/zsh-claudecode-completion

# Add Homebrew completions to FPATH before compinit
[[ -n "$HOMEBREW_PREFIX" ]] && FPATH="$HOMEBREW_PREFIX/share/zsh/site-functions:$FPATH"

# Add custom completions to FPATH (highest priority - added last so it's first)
[[ -d ~/.zfunc ]] && FPATH="$HOME/.zfunc:$FPATH"

# Load completion system (full rebuild once daily, cached otherwise)
autoload -Uz compinit
local zcomp="$HOME/.zcompdump"
if [[ ! -f "$zcomp" ]] || [[ $(( $(date +%s) - $(stat -f%m "$zcomp" 2>/dev/null || echo 0) )) -gt 86400 ]]; then
  compinit
else
  compinit -C
fi

# FZF tab (must load after compinit but before widget-wrapping plugins)
zinit wait"0a" silent for \
    Aloxaf/fzf-tab

zsh-defer -c "
  zstyle ':fzf-tab:*' use-fzf-default-opts yes
  zstyle ':fzf-tab:*' fzf-flags --height=~60%
"

# Fast Syntax Highlighting
zinit wait"1a" silent atload"fast-theme -q XDG:catppuccin-mocha" for \
    zdharma-continuum/fast-syntax-highlighting

# Suggestions
zinit wait"1b" silent atload"!_zsh_autosuggest_start" for \
    zsh-users/zsh-autosuggestions

# Pair matching
zinit wait"1c" silent for \
    raisedadead/zsh-smartinput

# PNPM completions
zinit wait"1d" silent atload"zpcdreplay" atclone"./zplug.zsh" atpull"%atclone" for \
    g-plane/pnpm-shell-completion

# Touch file with paths
zinit wait"2a" silent for \
    raisedadead/zsh-touchplus

# Wakatime
zinit wait"2b" silent for \
    sobolevn/wakatime-zsh-plugin

#-----------------------------------------------------------
# Tool Integrations
#-----------------------------------------------------------

if [[ -o interactive ]]; then
  # Sync inits (hooks in place before first prompt — no post-prompt re-renders)
  cached_evalz atuin "atuin init zsh --disable-up-arrow"
  cached_evalz zoxide "zoxide init --cmd cd --hook pwd zsh"

  # Deferred inits and completions (cached = instant source, no subprocess spawn)
  zsh-defer -c 'cached_evalz direnv "direnv hook zsh"'
  zsh-defer -c 'cached_evalz gh "gh completion -s zsh"'
  zsh-defer -c 'cached_evalz op "op completion zsh" && compdef _op op'
  zsh-defer -c 'cached_evalz but "but completions zsh"'
  zsh-defer -c 'cached_evalz wrangler "wrangler complete zsh"'
  # zsh-defer -c 'cached_evalz pkgx "pkgx --shellcode"'
fi

# File sourcing
zsh-defer source ~/.alias.zshrc
zsh-defer source ~/.private.zshrc
zsh-defer -c '[[ -f "$HOME/.local/bin/env" ]] && source "$HOME/.local/bin/env"'
zsh-defer -c '[[ -f ~/.bin/functions.sh ]] && source ~/.bin/functions.sh'
zsh-defer -c 'can_haz homeshick && export HOMESHICK_DIR=/opt/homebrew/opt/homeshick && source /opt/homebrew/opt/homeshick/homeshick.sh'

# Config compilation (recompile when source is newer than .zwc)
zsh-defer -c '
  for f in ~/.zshrc ~/.zshenv ~/.alias.zshrc; do
    [[ -f "$f" ]] && [[ ! -f "$f.zwc" || "$f" -nt "$f.zwc" ]] && zcompile "$f"
  done
'

# Homebrew must precede /usr/bin in PATH to avoid system binaries taking priority.
# fnm must load after Homebrew so fnm-managed Node.js overrides Homebrew's Node.js.
export PATH="/opt/homebrew/bin:$PATH"
cached_evalz fnm "fnm env --use-on-cd --version-file-strategy=recursive --resolve-engines --log-level=quiet"

# Performance profiling
[[ "$ZPROF" = true ]] && zprof
#-----------------------------------------------------------
# End of .zshrc
#-----------------------------------------------------------
