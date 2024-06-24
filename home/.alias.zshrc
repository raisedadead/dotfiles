#-----------------------------------------------------------
#
# @raisedadead's config files
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

#----------------------------
# LazyGit
#----------------------------
type brew &>/dev/null && [ -f $(brew --prefix)/bin/lazygit ] && alias g="lazygit"

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
alias vim="vi"
type brew &>/dev/null && [ -f $(brew --prefix)/bin/nvim ] && alias vi="nvim"

#-----------------------------
# update packages
#-----------------------------
alias letsupdate-brew-macos="brew update; brew upgrade; brew upgrade --cask; brew cleanup; brew doctor"
alias letsupdate-brew-linux="brew update; brew upgrade; brew cleanup; brew doctor"
alias letsupdate-xcode="sudo rm -rf /Library/Developer/CommandLineTools ; xcode-select --install"
type node &>/dev/null && alias letsupdate-node="nvm install --lts --reinstall-packages-from=$(node -v) --latest-npm --default"

#-----------------------------
# random string/key generator
#-----------------------------
alias genrand="head -c32 /dev/urandom | base64"

#-----------------------------
# Eza
#-----------------------------
type eza &>/dev/null && alias ls='eza --icons --group-directories-first'
type eza &>/dev/null && alias ll='eza -l --icons --no-user --group-directories-first  --time-style long-iso'
type eza &>/dev/null && alias la='eza -la --icons --no-user --group-directories-first  --time-style long-iso'

#-----------------------------
# Open Websites in Browser
#-----------------------------
type open &>/dev/null && alias ogo="open https://google.com"
type open &>/dev/null && alias ogi="open https://github.com"

#-----------------------------
# GitHub Copilot CLI
#-----------------------------
type github-copilot-cli &>/dev/null && eval "$(github-copilot-cli alias -- "$0")"

#-----------------------------
# Random String for passwords
#-----------------------------
type openssl &>/dev/null && alias genpass='openssl rand -base64 32'

#-----------------------------
# Multipass
#-----------------------------
type multipass &>/dev/null && alias mp="multipass"

