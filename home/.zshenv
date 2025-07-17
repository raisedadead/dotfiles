#-----------------------------------------------------------
# @raisedadead's config files
# Copyright: Mrugesh Mohapatra <https://mrugesh.dev>
# License: ISC
#
# File name: .zshenv
#-----------------------------------------------------------

# Skip loading for global system scripts
[[ -o no_global_rcs ]] && return

# Core environment variables
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export XDG_CONFIG_HOME="$HOME/.config"
export RIPGREP_CONFIG_PATH="$XDG_CONFIG_HOME/ripgrep/config"

# Editor configuration
if command -v nvim >/dev/null 2>&1; then
  export VISUAL=nvim
elif command -v vim >/dev/null 2>&1; then
  export VISUAL=vim
else
  export VISUAL=vi
fi
export EDITOR="$VISUAL"

# Homebrew (needs to be early in PATH)
if [[ -d /opt/homebrew ]]; then 
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -d /home/linuxbrew ]]; then 
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Cache brew prefix to avoid repeated calls
if command -v brew >/dev/null 2>&1; then
  export HOMEBREW_PREFIX="$(brew --prefix)"
fi

# Programming languages PATH setup
# Rust
[[ -d "$HOME/.cargo" ]] && export PATH="$HOME/.cargo/bin:$PATH"

# Go
if command -v go >/dev/null 2>&1; then
  GOPATH="$(go env GOPATH 2>/dev/null)"
  [[ -n "$GOPATH" ]] && export PATH="$PATH:$GOPATH/bin"
fi

# Ruby (via Homebrew)
if [[ -n "$HOMEBREW_PREFIX" ]] && [[ -d "$HOMEBREW_PREFIX/opt/ruby" ]]; then
  export PATH="$HOMEBREW_PREFIX/opt/ruby/bin:$PATH"
  export GEM_HOME="$HOME/.gem"
  export PATH="$GEM_HOME/bin:$PATH"
fi

# Python environment
# if [[ -d "$HOME/.pyenv" ]]; then
#   export PYENV_ROOT="$HOME/.pyenv"
#   export PATH="$PYENV_ROOT/bin:$PATH"
# fi

# MySQL client
if [[ -n "$HOMEBREW_PREFIX" ]] && [[ -d "$HOMEBREW_PREFIX/opt/mysql-client" ]]; then
  export PATH="$HOMEBREW_PREFIX/opt/mysql-client/bin:$PATH"
fi

# Local bin directories (should be last to override system commands)
[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"
[[ -d "$HOME/bin" ]] && export PATH="$HOME/bin:$PATH"

# Remove duplicate PATH entries
typeset -U PATH path
#-----------------------------------------------------------
# End of .zshenv
#-----------------------------------------------------------
