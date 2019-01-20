#-----------------------------------------------------------
#
# @raisedadead's config files
# https://git.raisedadead.com/dotfiles
#
# Copyright: Mrugesh Mohapatra <https://raisedadead.com>
# License: ISC
#
# File name: .zshrc
#
#-----------------------------------------------------------

#-----------------------------------------------------------
# common configs
#-----------------------------------------------------------

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
# fzf
#-----------------------------

[ -f $HOME/.fzf.zsh ] && source $HOME/.fzf.zsh

#-----------------------------
# travis
#-----------------------------
[ -f ~/.travis/travis.sh ] && source ~/.travis/travis.sh

#-----------------------------
# hub
#-----------------------------

[ -d $HOME/hub ] && export PATH=$PATH:$HOME/hub/bin

#-----------------------------
# homeshick
#-----------------------------
source "$HOME/.homesick/repos/homeshick/homeshick.sh"
fpath=($HOME/.homesick/repos/homeshick/completions $fpath)

#-----------------------------
# macOS
#-----------------------------
[ -f $HOME/.zshrc.mac-os ] && source $HOME/.zshrc.mac-os

#-----------------------------
# Zplug
#-----------------------------
[ -f $HOME/.zshrc.zplug ] && source $HOME/.zshrc.zplug

#-----------------------------
# aliases
#-----------------------------

source $HOME/.alias

#-----------------------------
# private configs
#-----------------------------
[ -f $HOMR/.zshrc.private ] && source $HOME/.zshrc.private

#-----------------------------
# Autocomplete settings
#-----------------------------

autoload -U compinit && compinit

#-----------------------------------------------------------
