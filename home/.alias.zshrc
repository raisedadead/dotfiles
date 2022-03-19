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
[ -f $(brew --prefix)/bin/fuck ] && eval $(thefuck --alias)

#-----------------------------
# Neovim
#-----------------------------
if [ -f $(brew --prefix)/bin/nvim ]; then
    alias vi="nvim"
    alias vim="nvim"
fi

#-----------------------------
# update packages
#-----------------------------
alias letsupdate-brew-linux="brew update ; brew upgrade ; brew cleanup ; brew doctor"
alias letsupdate-brew-macos="brew update ; brew upgrade ; brew cask upgrade ; brew cleanup ; brew doctor ; brew file push"
alias letsupdate-xcode="sudo rm -rf /Library/Developer/CommandLineTools ; xcode-select --install"
alias letsupdate-node="nvm install 'lts/*' --reinstall-packages-from=default --latest-npm"