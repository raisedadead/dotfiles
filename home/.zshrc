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

#-----------------------------
# homeshick
#-----------------------------
source ~/.homesick/repos/homeshick/homeshick.sh
fpath=(~/.homesick/repos/homeshick/completions $fpath)

#-----------------------------
# macOS
#-----------------------------
[ -f ~/.zshrc.macos ] && source ~/.zshrc.macos

#-----------------------------
# Linux
#-----------------------------
[ -f ~/.zshrc.linux ] && source ~/.zshrc.linux

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
# Brew Completions for zsh
#-----------------------------
if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh/site-functions:$FPATH
fi

#-----------------------------
# Starship Prompt for zsh
#-----------------------------
if type starship &>/dev/null; then
  eval "$(starship init zsh)"
fi

#-----------------------------
# fzf
#-----------------------------

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
[ -f ~/.fzf.zshrc ] && source ~/.fzf.zshrc

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
