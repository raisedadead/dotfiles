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
# fzf
#-----------------------------

[ -f $HOME/.fzf.zsh ] && source $HOME/.fzf.zsh
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS'
	--color=dark
	--color=fg:-1,bg:-1,hl:#5fff87,fg+:-1,bg+:-1,hl+:#ffaf5f
	--color=info:#af87ff,prompt:#5fff87,pointer:#ff87d7,marker:#ff87d7,spinner:#ff87d7
	'

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
# aliases and env variables
#-----------------------------

[ -f $HOME/.alias ] && source $HOME/.alias
[ -f $HOME/.profile ] && source $HOME/.profile

#-----------------------------
# custom utils and functions
#-----------------------------
[ -f $HOME/.bin/functions.sh ] && source $HOME/.bin/functions.sh

#-----------------------------
# private configs
#-----------------------------
[ -f $HOME/.zshrc.private ] && source $HOME/.zshrc.private

#-----------------------------
# Autocomplete settings
#-----------------------------

autoload -Uz compinit
compinit

#-----------------------------
# Path and variable settings
#-----------------------------

export PATH=“$HOME/.gem/ruby/2.6.0/bin:$PATH”
export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"
export VISUAL=nvim
export EDITOR="$VISUAL"


#-----------------------------
# VIM Mode in ZSH
#-----------------------------
# bindkey -v

# Uncomment for profiling load time
# zprof >> ~/.zsh-load-log.txt
#-----------------------------------------------------------


autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /usr/local/bin/terraform terraform
