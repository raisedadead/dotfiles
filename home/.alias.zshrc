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
# update packages
#-----------------------------
alias letsupdate-brew-macos="export HOMEBREW_NO_ENV_HINTS=1;brew update; brew upgrade; brew upgrade --cask; brew cleanup; brew doctor"
alias letsupdate-brew-linux="brew update; brew upgrade; brew cleanup; brew doctor"
alias letsupdate-xcode="sudo rm -rf /Library/Developer/CommandLineTools ; xcode-select --install"

#-----------------------------
# random string/key generator
#-----------------------------
alias genrand="head -c32 /dev/urandom | base64"
alias genpass='openssl rand -base64 32'

#-----------------------------
# Eza
#-----------------------------
if can_haz eza; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -l --icons --no-user --group-directories-first --time-style long-iso'
  alias ls-all='eza -la --icons --no-user --group-directories-first --time-style long-iso'
  alias ls-plain='eza -la --icons=never --no-permissions --no-filesize --no-time --no-user'
fi

