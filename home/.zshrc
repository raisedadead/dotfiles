#-----------------------------------------------------------
# @raisedadead's config files
# Copyright: Mrugesh Mohapatra <https://mrugesh.dev>
# License: ISC
#
# File name: .zshrc
#-----------------------------------------------------------

if [[ "$ZPROF" = true ]]; then zmodload zsh/zprof; fi

export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export XDG_CONFIG_HOME="$HOME/.config"
export RIPGREP_CONFIG_PATH="$XDG_CONFIG_HOME/ripgrep/config"

umask 022
limit coredumpsize 0
autoload -Uz compinit && compinit

setopt INC_APPEND_HISTORY HIST_EXPIRE_DUPS_FIRST HIST_IGNORE_DUPS HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE HIST_FIND_NO_DUPS HIST_SAVE_NO_DUPS

function can_haz() {
  command -v "$1" >/dev/null 2>&1
}

# ZSH Plugins
[ -f ~/.zinit.zshrc ] && source ~/.zinit.zshrc
[ -f ~/.private.zshrc ] && source ~/.private.zshrc

# Homeshick for dotfiles
source ~/.homesick/repos/homeshick/homeshick.sh
fpath=(~/.homesick/repos/homeshick/completions $fpath)

# Homebrew
if [[ -d /opt/homebrew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
if [[ -d /home/linuxbrew ]]; then eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"; fi

# Rust
if [[ -d "$HOME/.cargo" ]]; then
  export CARGO_HOME="$HOME/.cargo"
  export PATH="$CARGO_HOME/bin:$PATH"
fi

# Ruby
if can_haz brew && [[ -d "$(brew --prefix ruby)" ]]; then
  export PATH="$(brew --prefix ruby)/bin:$PATH"
  export GEM_HOME=$HOME/.gem
  export PATH=$GEM_HOME/bin:$PATH
fi

# Python
# if can_haz brew && can_haz pyenv; then
#   export PYENV_ROOT="$HOME/.pyenv"
#   [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
#   eval "$(pyenv init -)"
#   alias brew='env PATH="${PATH//$(pyenv root)\/shims:/}" brew'
# fi
[ -f "$HOME/bin/env" ] && . "$HOME/.local/bin/env"

# PNPM
if [[ -d "$HOME/.pnpm" ]]; then
  export PNPM_HOME="$HOME/.pnpm"
  export PATH="$PNPM_HOME:$PATH"
elif [[ -d "$HOME/Library/pnpm" ]]; then
  export PNPM_HOME="$HOME/Library/pnpm"
  export PATH="$PNPM_HOME:$PATH"
fi

# Golang
if can_haz go && [[ -d "$GOPATH/bin" ]]; then
  export PATH="$PATH:$(go env GOPATH)/bin"
fi

# MySQL
if can_haz brew && [[ -d "$(brew --prefix)/opt/mysql-client" ]]; then
  export PATH="$(brew --prefix)/opt/mysql-client/bin:$PATH"
fi

# NVIM
if can_haz nvim; then
  export VISUAL=nvim
elif can_haz vim; then
  export VISUAL=vim
else
  export VISUAL=vi
fi
export EDITOR="$VISUAL"

# Additional completions
[ -f ~/.bin/completions/main.sh ] && source ~/.bin/completions/main.sh

# Brew completions
if can_haz brew; then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
fi

# fzf
if can_haz fzf; then
  [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
  [ -f ~/.fzf.zshrc ] && source ~/.fzf.zshrc
fi

# Custom utils and functions
[ -f ~/.bin/functions.sh ] && source ~/.bin/functions.sh
[ -f ~/.bin/tailscale-mgmt.sh.sh ] && source ~/.bin/tailscale-mgmt.sh

# Atuin
if can_haz atuin; then
  eval "$(atuin init zsh --disable-up-arrow)"
fi

# zoxide
if can_haz zoxide; then
  eval "$(zoxide init --cmd cd --hook pwd zsh)"
fi

# pkgx
if can_haz pkgx; then
  source <(pkgx --shellcode)
fi

# Starship Prompt for zsh
if can_haz starship; then
  eval "$(starship init zsh)"
fi

# direnv
if can_haz direnv; then
  eval "$(direnv hook zsh)"
fi

# Aliases and env settings
[ -f ~/.alias.zshrc ] && source ~/.alias.zshrc
[ -f ~/.profile ] && source ~/.profile

# Profiling
timezsh() {
  for i in {1..10}; do time zsh -i -c exit; done
}

if [[ "$ZPROF" = true ]]; then zprof; fi

#------------------------------------------------------------
# Automatic additions (Review and clean up)
#------------------------------------------------------------

