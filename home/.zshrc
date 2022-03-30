#-----------------------------------------------------------
#
# @raisedadead's config files
# https://get.ms/dotfiles
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

# Uncomment for profiling load time
# zmodload zsh/zprof

export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

umask 022
limit coredumpsize 0
bindkey -d

# Return if zsh is called from Vim
if [[ -n $VIMRUNTIME ]]; then
  return 0
fi

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
# linuxbrew
#-----------------------------
[ -d /home/linuxbrew ] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

#-----------------------------
# Brew Completions for zsh
#-----------------------------
if can_haz brew; then
  FPATH=$(brew --prefix)/share/zsh/site-functions:$FPATH
fi

#-----------------------------
# pyenv
#-----------------------------
export PATH="$HOME/.pyenv/bin:$PATH"
[ -d $HOME/.pyenv ] && eval "$(pyenv init --path)"
# avoid conflicts with homebrew
[ -d $HOME/.pyenv ] && alias brew='env PATH="${PATH//$(pyenv root)\/shims:/}" brew'

#-----------------------------
# Zplug
#-----------------------------
[ -f ~/.zshrc.zplug ] && source ~/.zshrc.zplug

#-----------------------------
# custom utils and functions
#-----------------------------
[ -f ~/.bin/functions.sh ] && source ~/.bin/functions.sh

#-----------------------------
# private configs and secrets
#-----------------------------
[ -f ~/.zshrc.private ] && source ~/.zshrc.private

#-----------------------------
# Path and variable settings
#-----------------------------
export PATH="$HOME/.cargo/bin:$PATH"
export VISUAL=nvim
export EDITOR="$VISUAL"

#-----------------------------
# Completions
#-----------------------------
if can_haz brew; then
  FPATH=$(brew --prefix)/share/zsh/site-functions:$FPATH
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
# aliases and env settings
#-----------------------------
[ -f ~/.alias.zshrc ] && source ~/.alias.zshrc
[ -f ~/.profile ] && source ~/.profile

#-----------------------------
# Autocomplete settings
#-----------------------------
autoload -Uz compinit
compinit

# Uncomment for profiling load time
# zprof >> ~/.zsh-load-log.txt
#-----------------------------------------------------------

# Warning: Everything below this line was probably added automatically.
