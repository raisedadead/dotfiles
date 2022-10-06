#-----------------------------------------------------------
#
# @raisedadead's config files
# https://get.ms/dotfiles
#
# Copyright: Mrugesh Mohapatra <https://mrugesh.dev>
# License: ISC
#
# File name: .alias.zshrc
#
#-----------------------------------------------------------

#-----------------------------
# homeshick helpers
#-----------------------------
alias home="homeshick"

#-----------------------------
# Other Git aliases
# ----------------------------
alias gti="git"
alias got="git"
alias gut="git"

#-----------------------------
# VM lists from Azure and DO
#-----------------------------
alias dovms="doctl compute droplet list --format \"ID,Name,PublicIPv4\""
alias azvms="az vm list-ip-addresses --output table"

#-----------------------------
# thefuck - mistyped commands
#-----------------------------
type brew &>/dev/null && [ -f $(brew --prefix)/bin/fuck ] && eval $(thefuck --alias)
#-----------------------------
# Neovim
#-----------------------------
type brew &>/dev/null && [ -f $(brew --prefix)/bin/nvim ] && alias vi="nvim"; alias vim="nvim"

#-----------------------------
# update packages
#-----------------------------
export brewupdatecmd="brew update; brew upgrade; brew upgrade --cask; brew cleanup; brew doctor;"
type brew &>/dev/null && [ -f $(brew --prefix)/bin/brew-file ] && export brewupdatecmd="brew file update;brew cleanup; brew doctor;"

alias letsupdate-brew-macos=$brewupdatecmd
alias letsupdate-brew-linux="brew update; brew upgrade; brew cleanup; brew doctor"
alias letsupdate-xcode="sudo rm -rf /Library/Developer/CommandLineTools ; xcode-select --install"
alias letsupdate-node="nvm install 'lts/*' --reinstall-packages-from=default --latest-npm"

#-----------------------------
# random string/key generator
#-----------------------------
alias genrand="head -c32 /dev/urandom | base64"

