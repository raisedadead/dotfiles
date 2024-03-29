#-----------------------------------------------------------
#
# @raisedadead's config files
# Copyright: Mrugesh Mohapatra <https://mrugesh.dev>
# License: ISC
#
# File name: .zplug.zshrc
#
#-----------------------------------------------------------

#-----------------------------
# Check if zplug is installed
#-----------------------------
if [[ ! -d ~/.zplug ]]; then
  git clone https://github.com/zplug/zplug ~/.zplug
fi
source ~/.zplug/init.zsh

#-----------------------------
# My custom plugins
#-----------------------------
zplug "raisedadead/zsh-touchplus", defer:2

GSO_ENABLE_KEYBINDINGS=true
zplug "raisedadead/zsh-gso", defer:2

#-----------------------------
# Node.js
#-----------------------------
NVM_AUTO_USE=true
zplug "lukechilds/zsh-nvm"
zplug "lukechilds/zsh-better-npm-completion", defer:2
zplug "g-plane/pnpm-shell-completion", hook-build:"./zplug.zsh", defer:2
#-----------------------------
# Files & directories
#-----------------------------
# zplug "b4b4r07/enhancd", use:init.sh
zplug "mfaerevaag/wd"

#-----------------------------
# Git
#-----------------------------
zplug "z-shell/zsh-diff-so-fancy"
zplug "bigH/git-fuzzy", as:command, use:"bin/git-fuzzy"
zplug "raisedadead/d3733e244918a0d2030a936b4b6e9dbd", from:gist, as:command, rename-to:git-bare-clone, use:bare-clone.sh

#-----------------------------
# Syntax highlighting
#-----------------------------
zplug "zdharma-continuum/fast-syntax-highlighting", defer:2
zplug "catppuccin/zsh-syntax-highlighting", as:theme, use:"themes/catppuccin_mocha-zsh-syntax-highlighting", defer:2

#-----------------------------
# vim mode
#-----------------------------
zplug "softmoth/zsh-vim-mode"

#-----------------------------
# Docker
#-----------------------------
zplug "srijanshetty/docker-zsh", defer:2

#-----------------------------
# Smart Input (bracket matching)
#-----------------------------
zplug "raisedadead/zsh-smartinput", defer:2

#-----------------------------
# zsh-users
#-----------------------------
# zplug "zsh-users/zsh-completions", defer:2
zplug "zsh-users/zsh-autosuggestions", defer:2
zplug "zsh-users/zsh-history-substring-search", defer:2

#-----------------------------
# oh-my-zsh
#-----------------------------
zplug "lib/history", from:oh-my-zsh
zplug "lib/directories", from:oh-my-zsh

#-----------------------------
# wakatime
#-----------------------------
zplug "sobolevn/wakatime-zsh-plugin", defer:2

if can_haz fzf; then
  #-----------------------------
  # History
  #-----------------------------
  # zplug "joshskidmore/zsh-fzf-history-search"
  #-----------------------------
  # Completions
  #-----------------------------
  zplug "Aloxaf/fzf-tab", defer:2
  # zplug "marlonrichert/zsh-autocomplete", defer:2
fi

#-----------------------------
# Install plugins if there are plugins that have not been installed
#-----------------------------
if ! zplug check --verbose; then
  printf "Install? [y/N]: "
  if read -q; then
    echo
    zplug install
  fi
fi

#-----------------------------
# Then, source plugins and add commands to $PATH
#-----------------------------
# zplug load --verbose
zplug load
