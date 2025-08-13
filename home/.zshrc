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

# Force emacs mode (prevent vi mode auto-activation from EDITOR=nvim)
bindkey -e

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

# Compile zinit and plugins for faster loading
zsh-defer -c "zinit compile --all 2>/dev/null"

# Load completions before compinit (per zsh-completions guidelines)
zinit light zsh-users/zsh-completions

# Add Homebrew completions to FPATH before compinit
[[ -n "$HOMEBREW_PREFIX" ]] && FPATH="$HOMEBREW_PREFIX/share/zsh/site-functions:$FPATH"

# Load completion system immediately (required for fzf-tab)
autoload -Uz compinit && compinit -C

# FZF tab (must load after compinit but before widget-wrapping plugins)
zinit wait"0a" silent for \
    Aloxaf/fzf-tab
zsh-defer -c "
  # Disable sort when completing git checkout
  zstyle ':completion:*:git-checkout:*' sort false
  # Set descriptions format to enable group support
  zstyle ':completion:*:descriptions' format '[%d]'
  # Set list-colors to enable filename colorizing
  zstyle ':completion:*' list-colors \${(s.:.)LS_COLORS}
  # Force zsh not to show completion menu, which allows fzf-tab to capture the unambiguous prefix
  zstyle ':completion:*' menu no
  # Preview directory's content with eza when completing cd
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always \$realpath'
  # Switch group using < and >
  zstyle ':fzf-tab:*' switch-group '<' '>'
  # Existing user configurations
  zstyle ':fzf-tab:*' use-fzf-default-opts yes
  zstyle ':fzf-tab:*' fzf-flags --height=~25%
"

# Fast Syntax Highlighting
zinit wait"0b" silent for \
      atload'fast-theme -q XDG:rose-pine-moon' \
    zdharma-continuum/fast-syntax-highlighting 

# Suggestions
zinit wait"0c" silent for \
    atload"!_zsh_autosuggest_start" zsh-users/zsh-autosuggestions

# Pair matching
zinit wait"0d" silent for \
    raisedadead/zsh-smartinput

# PNPM completions
zinit wait"1c" silent atload"zpcdreplay" atclone"./zplug.zsh" atpull"%atclone" for \
    g-plane/pnpm-shell-completion

# Touch file with paths
zinit wait"2a" silent for \
    raisedadead/zsh-touchplus

# Wakatime
zinit wait"3a" silent for \
    sobolevn/wakatime-zsh-plugin

#-----------------------------------------------------------
# Tool Integrations
#-----------------------------------------------------------

# Node.js version manager (fnm)
eval "$(fnm env --use-on-cd --version-file-strategy=recursive --corepack-enabled --resolve-engines)"

# FZF
zsh-defer source ~/.fzf.zshrc
zsh-defer source ~/.fzf.zsh

# Modern tools (interactive only)
if [[ -o interactive ]]; then
  zsh-defer -c 'can_haz atuin && eval "$(atuin init zsh --disable-up-arrow)"'
  zsh-defer -c 'can_haz zoxide && eval "$(zoxide init --cmd cd --hook pwd zsh)"'
  zsh-defer -c 'can_haz direnv && eval "$(direnv hook zsh)"'
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

# This ensures that PATH is set for homebrew
export PATH="/opt/homebrew/bin:$PATH"

# Performance profiling
[[ "$ZPROF" = true ]] && zprof
#-----------------------------------------------------------
# End of .zshrc
#-----------------------------------------------------------
