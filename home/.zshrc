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

# Fig pre block. Keep at the top of this file.
[[ -f "$HOME/.fig/shell/zshrc.pre.zsh" ]] && . "$HOME/.fig/shell/zshrc.pre.zsh"

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
if [[ -n $VIMRUNTIME ]]; then
  return 0
fi

setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_FIND_NO_DUPS

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
# pyenv
#-----------------------------
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
[ -d $PYENV_ROOT ] && eval "$(pyenv init --path)"
# avoid conflicts with homebrew
[ -d $PYENV_ROOT ] && alias brew='env PATH="${PATH//$(pyenv root)\/shims:/}" brew'

#-----------------------------
# Zplug
#-----------------------------
[ -f ~/.zplug.zshrc ] && source ~/.zplug.zshrc

#-----------------------------
# custom utils and functions
#-----------------------------
[ -f ~/.bin/functions.sh ] && source ~/.bin/functions.sh

#-----------------------------
# private configs and secrets
#-----------------------------
[ -f ~/.private.zshrc ] && source ~/.private.zshrc

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

# Use for profiling zsh, should be the last thing in the file
timezsh() {
  for i in $(seq 1 10); do time zsh -i -c exit; done
}

if [[ "$ZPROF" = true ]]; then
  zprof
fi
#-----------------------------------------------------------

# Fig post block. Keep at the bottom of this file.
[[ -f "$HOME/.fig/shell/zshrc.post.zsh" ]] && . "$HOME/.fig/shell/zshrc.post.zsh"

# Warning: Everything below this line was probably added automatically.
