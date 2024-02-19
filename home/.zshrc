#-----------------------------------------------------------
#
# @raisedadead's config files
#
# Copyright: Mrugesh Mohapatra <https://mrugesh.dev>
# License: ISC
#
# File name: .zshrc
#
#-----------------------------------------------------------

#-----------------------------------------------------------
# common configs
#-----------------------------------------------------------

# Use for profiling zsh, should be the first thing in the file
if [[ "$ZPROF" = true ]]; then
  zmodload zsh/zprof
fi

export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

umask 022
limit coredumpsize 0
bindkey -d

# Return if zsh is called from Vim
# if [[ -n $VIMRUNTIME ]]; then
#   return 0
# fi

setopt INC_APPEND_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS

# Credit: https://github.com/unixorn/zsh-quickstart-kit/blob/6e940dd38053b0a7c6c0208426d7a7ab798a3db7/zsh/.zshrc#L24-L26
function can_haz() {
  which "$@" >/dev/null 2>&1
}

#-----------------------------
# homeshick
#-----------------------------
source ~/.homesick/repos/homeshick/homeshick.sh
fpath=(~/.homesick/repos/homeshick/completions $fpath)

#-----------------------------
# homebrew
#-----------------------------
[ -d /opt/homebrew ] && eval "$(/opt/homebrew/bin/brew shellenv)"

#-----------------------------
# linuxbrew
#-----------------------------
[ -d /home/linuxbrew ] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

#-----------------------------
# Zplug
#-----------------------------
[ -f ~/.zplug.zshrc ] && source ~/.zplug.zshrc

#-----------------------------
# pyenv
#-----------------------------
if can_haz brew && [[ -d "$(brew --prefix)/bin/pyenv" ]]; then
  eval "$(pyenv init -)"
fi
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
[ -d $PYENV_ROOT ] && eval "$(pyenv init --path)"
# avoid conflicts with homebrew
[ -d $PYENV_ROOT ] && alias brew='env PATH="${PATH//$(pyenv root)\/shims:/}" brew'

#-----------------------------
# private configs and secrets
#-----------------------------
[ -f ~/.private.zshrc ] && source ~/.private.zshrc

#-----------------------------
# Path and variable settings
#-----------------------------
# cargo
if [[ -d "$HOME/.cargo" ]]; then
  export CARGO_HOME="$HOME/.cargo"
  export PATH="$CARGO_HOME/bin:$PATH"
fi

# pnpm
if [[ -d "$HOME/.pnpm" ]]; then
  export PNPM_HOME="$HOME/.pnpm"
  export PATH="$PNPM_HOME:$PATH"
elif [[ -d "$HOME/Library/pnpm" ]]; then
  export PNPM_HOME="$HOME/Library/pnpm"
  export PATH="$PNPM_HOME:$PATH"
fi

# editor
if can_haz nvim; then
  export VISUAL=nvim
else
  export VISUAL=vim
fi
export EDITOR="$VISUAL"

# mysql
if can_haz brew && [[ -d "$(brew --prefix)/opt/mysql-client" ]]; then
  export PATH="$(brew --prefix)/opt/mysql-client/bin:$PATH"
fi

#-----------------------------
# Completions
#-----------------------------
# Add more completions in this file only
[ -f ~/.bin/completions/main.sh ] && source ~/.bin/completions/main.sh

# ZSH completions
if can_haz brew; then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
fi

#-----------------------------
# Starship Prompt for zsh
#-----------------------------
if can_haz starship; then
  eval "$(starship init zsh)"
fi

#-----------------------------
# fzf
#-----------------------------
if can_haz fzf; then
  [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
  [ -f ~/.fzf.zshrc ] && source ~/.fzf.zshrc
fi

#-----------------------------
# custom utils and functions
#-----------------------------
[ -f ~/.bin/functions.sh ] && source ~/.bin/functions.sh

#-----------------------------
# atuin
#-----------------------------
if can_haz atuin; then
  eval "$(atuin init zsh --disable-up-arrow)"
fi

#-----------------------------
# zoxide
#-----------------------------
if can_haz zoxide; then
  eval "$(zoxide init --cmd cd --hook pwd zsh)"
fi

#-----------------------------
# pkgx
#-----------------------------
if can_haz pkgx; then
 source <(pkgx --shellcode)
fi 

# aliases and env settings
#-----------------------------
[ -f ~/.alias.zshrc ] && source ~/.alias.zshrc
[ -f ~/.profile ] && source ~/.profile

if [[ $TERM_PROGRAM != "WarpTerminal" ]]; then
  ##### WHAT YOU WANT TO DISABLE FOR WARP - BELOW

  #-----------------------------
  # iTerm2 settings
  #-----------------------------
  if can_haz test; then
    if test -e "${HOME}/.iterm2_shell_integration.zsh"; then
      source "${HOME}/.iterm2_shell_integration.zsh"
    fi
  fi

 ##### WHAT YOU WANT TO DISABLE FOR WARP - ABOVE
fi

#-----------------------------
# Autocomplete settings
#-----------------------------
autoload -Uz compinit
compinit

# Use for profiling zsh, should be the last thing in the file
timezsh() {
  for i in $(seq 1 10); do time zsh -i -c exit; done
}

if [[ "$ZPROF" = true ]]; then
  zprof
fi
#-----------------------------------------------------------

# Warning: Everything below this line was probably added automatically.

