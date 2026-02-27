#-----------------------------------------------------------
# @raisedadead's config files
# Copyright: Mrugesh Mohapatra <https://mrugesh.dev>
# License: ISC
#
# File name: .alias.zshrc
#-----------------------------------------------------------

#-----------------------------
# homeshick helpers
#-----------------------------
alias home="homeshick"

#-----------------------------
# cat
#-----------------------------
can_haz bat && alias cat="bat"

#-----------------------------
# Other Git aliases
#----------------------------
alias gti="git"
alias got="git"
alias gut="git"

#----------------------------
# LazyGit
#----------------------------
can_haz lazygit && alias g="lazygit"

#----------------------------
# LazyDocker
#----------------------------
can_haz lazydocker && alias d="lazydocker"

#----------------------------
# Code (VS Code, or others)
#----------------------------
alias c="$VISUAL ."

#-----------------------------
# VM lists from Azure and DO
#-----------------------------
alias dovms="doctl compute droplet list --format \"ID,Name,PublicIPv4\""
alias azvms="az vm list-ip-addresses --output table"

#-----------------------------
# Neovim
#-----------------------------
can_haz nvim && alias vi="nvim"
can_haz nvim && alias vim="nvim"

#-----------------------------
# random string/key generator
#-----------------------------
alias genrand='openssl rand -base64 32'
alias genpass='openssl rand -hex 32'

#-----------------------------
# wt (dev build)
#-----------------------------
if can_haz "$HOME/DEV/rd/wt/main/bin/wt"; then
  wt_bin="$HOME/DEV/rd/wt/main/bin/wt"
  alias wt-dev="$wt_bin"
  alias w="$wt_bin"
  unset wt_bin
fi

#-----------------------------
# Eza
#-----------------------------
if can_haz eza; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -l --icons --no-user --group-directories-first --time-style long-iso'
  alias ls-all='eza -la --icons --no-user --group-directories-first --time-style long-iso'
  alias ls-plain='eza -la --icons=never --no-permissions --no-filesize --no-time --no-user'
fi

