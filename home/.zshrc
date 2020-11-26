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

#-----------------------------
# VIM Mode in ZSH
#-----------------------------
bindkey -v

# Return if zsh is called from Vim
if [[ -n $VIMRUNTIME ]]; then
    return 0
fi

#-----------------------------
# fzf
#-----------------------------

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

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

[ -d ~/hub ] && export PATH=$PATH:~/hub/bin

#-----------------------------
# linuxbrew
#-----------------------------
[ -d /home/linuxbrew ] && eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)

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
# macOS
#-----------------------------
[ -f ~/.zshrc.linux ] && source ~/.zshrc.linux

#-----------------------------
# Zplug
#-----------------------------
[ -f ~/.zshrc.zplug ] && source ~/.zshrc.zplug

#-----------------------------
# aliases and env settings
#-----------------------------

[ -f ~/.alias ] && source ~/.alias
[ -f ~/.profile ] && source ~/.profile

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

# export PATH="~/.gem/ruby/2.6.0/bin:$PATH"
# export PATH="~/.yarn/bin:~/.config/yarn/global/node_modules/.bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
export VISUAL=nvim
export EDITOR="$VISUAL"

#-----------------------------
# Pyenv intialization
#-----------------------------
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi

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
# Autocomplete settings
#-----------------------------

autoload -Uz compinit
compinit

# Uncomment for profiling load time
# zprof >> ~/.zsh-load-log.txt
#-----------------------------------------------------------

