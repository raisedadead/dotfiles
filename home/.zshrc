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
can_haz() { command -v "$1" >/dev/null 2>&1 }
timezsh() { for i in {1..10}; do time zsh -i -c exit; done }

# Keybindings
bindkey -e  # Emacs mode
bindkey -M viins 'jk' vi-cmd-mode

# Prompt
can_haz starship && eval "$(starship init zsh)"

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

# Compile zinit and plugins for faster loading
zsh-defer -c "zinit compile --all 2>/dev/null"

# Load completions before compinit (per zsh-completions guidelines)
zinit light zsh-users/zsh-completions

# Add Homebrew completions to FPATH before compinit
[[ -n "$HOMEBREW_PREFIX" ]] && FPATH="$HOMEBREW_PREFIX/share/zsh/site-functions:$FPATH"

# Add custom completions to FPATH (highest priority - added last so it's first)
[[ -d ~/.zfunc ]] && FPATH="$HOME/.zfunc:$FPATH"

# Load completion system immediately
autoload -Uz compinit && compinit -C

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


# Modern tools (interactive only)
if [[ -o interactive ]]; then
  zsh-defer -c 'can_haz atuin && eval "$(atuin init zsh --disable-up-arrow)"'
  zsh-defer -c 'can_haz zoxide && eval "$(zoxide init --cmd cd --hook pwd zsh)"'
  zsh-defer -c 'can_haz direnv && eval "$(direnv hook zsh)"'
  zsh-defer -c 'can_haz gh && eval "$(gh completion -s zsh)"'
  zsh-defer -c 'can_haz op && eval "$(op completion zsh)"; compdef _op op'
  # zsh-defer -c 'can_haz pkgx && source <(pkgx --shellcode)'
fi

# File sourcing
zsh-defer source ~/.alias.zshrc
zsh-defer source ~/.private.zshrc
zsh-defer -c '[[ -f "$HOME/.local/bin/env" ]] && source "$HOME/.local/bin/env"'
zsh-defer -c '[[ -f ~/.bin/functions.sh ]] && source ~/.bin/functions.sh'
zsh-defer -c 'can_haz homeshick && export HOMESHICK_DIR=/opt/homebrew/opt/homeshick && source /opt/homebrew/opt/homeshick/homeshick.sh'

# Config compilation
zsh-defer -c "
  [[ -f ~/.zshrc && ! -f ~/.zshrc.zwc ]] && zcompile ~/.zshrc
  [[ -f ~/.zshenv && ! -f ~/.zshenv.zwc ]] && zcompile ~/.zshenv
  [[ -f ~/.alias.zshrc && ! -f ~/.alias.zshrc.zwc ]] && zcompile ~/.alias.zshrc
"

# Note: Homebrew is already in path via /etc/paths.d/homebrew,
#  but we need it here to avoid this:
#
#  ```
#  Warning: /usr/bin occurs before /opt/homebrew/bin in your PATH.
#  This means that system-provided programs will be used instead of those
#  provided by Homebrew.
#  ```
#
#  The probnlem is, this will make Node.js from homebrew,
#  if installed by a formula, or cask take precedence over
#  fnm-managed Node.js.
export PATH="/opt/homebrew/bin:$PATH"
#  so Node.js version manager (fnm) should be installed after Homebrew in path
eval "$(fnm env --use-on-cd --version-file-strategy=recursive --resolve-engines)" && clear

# Performance profiling
[[ "$ZPROF" = true ]] && zprof
#-----------------------------------------------------------
# End of .zshrc
#-----------------------------------------------------------

alias claude-mem='bun "/Users/mrugesh/.claude/plugins/marketplaces/thedotmack/plugin/scripts/worker-service.cjs"'
