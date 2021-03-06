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
# hub.github.com
#-----------------------------
[ -f $(brew --prefix)/bin/hub ] && alias git="hub"

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
[ -f $(brew --prefix)/bin/hub ] && eval $(thefuck --alias)


#-----------------------------
# Neovim
#-----------------------------
if [ -f $(brew --prefix)/bin/hub ]; then
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


#-----------------------------
# Quick lookup (and edit)
#-----------------------------
if $(type bat > /dev/null 2>&1) && $(type fd > /dev/null 2>&1) && $(type fzf > /dev/null 2>&1); then

  alias pbv='
  fd --type f \
     --hidden \
     --follow \
     --exclude .git | \
  fzf --height 80% \
      --layout reverse \
      --info inline \
      --border \
      --preview "bat --style=numbers --color=always {} | head -500" \
      --preview-window "down:24:noborder" \
      --color=dark \
      --color=fg:-1,bg:-1,hl:#5fff87,fg+:-1,bg+:-1,hl+:#ffaf5f \
      --color=info:#af87ff,prompt:#5fff87,pointer:#ff87d7,marker:#ff87d7,spinner:#ff87d7 \
  '

  alias psv='
  fd --type f \
     --hidden \
     --follow \
     --exclude .git | \
  fzf --preview "bat --style=numbers --color=always {} | head -500" \
  '

  alias v='vi $(pbv)'
fi
