#-----------------------------------------------------------
# @raisedadead's config files
# Copyright: Mrugesh Mohapatra <https://mrugesh.dev>
# License: ISC
#
# File name: .alias.zshrc
#-----------------------------------------------------------

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
# Brewfile
#----------------------------
can_haz brew && alias bu="cd ~/.config/brewfile && just update && just save"

#----------------------------
# LazyDocker
#----------------------------
can_haz lazydocker && alias d="lazydocker"

#----------------------------
# Claude
#----------------------------
alias c="claude --dangerously-skip-permissions"

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


#-----------------------------
# Tmux
#-----------------------------
if can_haz tmux; then
  alias t='tmux new-session -A -s "$(basename "$PWD" | sed "s/^\.//")" -c "$PWD"'
fi

#-----------------------------
# Universe CLI, dev mode
#-----------------------------
alias unidev='node /Users/mrugesh/DEV/fCC-U/universe-cli/dist/index.js'

#-----------------------------
# Format markdown
#-----------------------------
alias md-fmt='git ls-files -z "*.md" "*.markdown" | xargs -0 mdformat --wrap no'
alias md-check='git ls-files -z "*.md" "*.markdown" | xargs -0 mdformat --check --wrap no'
