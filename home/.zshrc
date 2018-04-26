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

umask 022
limit coredumpsize 0
bindkey -d

# Return if zsh is called from Vim
if [[ -n $VIMRUNTIME ]]; then
    return 0
fi

#-----------------------------
# Zplug
#-----------------------------
[ -f $HOME/.zshrc.zplug ] && source $HOME/.zshrc.zplug

#-----------------------------
# aliases
#-----------------------------

source $HOME/.alias

#-----------------------------
# homeshick
#-----------------------------
source "$HOME/.homesick/repos/homeshick/homeshick.sh"
fpath=($HOME/.homesick/repos/homeshick/completions $fpath)

#-----------------------------
# fzf
#-----------------------------

[ -f $HOME/.fzf.zsh ] && source $HOME/.fzf.zsh

#-----------------------------------------------------------
# macOS
#-----------------------------------------------------------
[ -f $HOME/.zshrc.mac-os ] && source $HOME/.zshrc.mac-os

#-----------------------------------------------------------

#-----------------------------------------------------------
# travis
#-----------------------------------------------------------
[ -f ~/.travis/travis.sh ] && source ~/.travis/travis.sh

#-----------------------------
# hub
#-----------------------------

[ -d $HOME/hub ] && export PATH=$PATH:$HOME/hub/bin

# tabtab source for serverless package
# uninstall by removing these lines or running `tabtab uninstall serverless`
[[ -f /home/raisedadead/DEV/open-api/node_modules/tabtab/.completions/serverless.zsh ]] && . /home/raisedadead/DEV/open-api/node_modules/tabtab/.completions/serverless.zsh
# tabtab source for sls package
# uninstall by removing these lines or running `tabtab uninstall sls`
[[ -f /home/raisedadead/DEV/open-api/node_modules/tabtab/.completions/sls.zsh ]] && . /home/raisedadead/DEV/open-api/node_modules/tabtab/.completions/sls.zsh