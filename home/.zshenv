#-----------------------------------------------------------
# @raisedadead's config files
# Copyright: Mrugesh Mohapatra <https://mrugesh.dev>
# License: ISC
#
# File name: .zshenv
#-----------------------------------------------------------

# Load OS detection utility
# source "$HOME/.bin/utils.sh"
# DOT_TARGET="$(_mrgsh_get_system)"
DOT_TARGET="macos"

# Skip loading for global system scripts
[[ -o no_global_rcs ]] && return

# Core environment variables
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export XDG_CONFIG_HOME="$HOME/.config"
export RIPGREP_CONFIG_PATH="$XDG_CONFIG_HOME/ripgrep/config"
export STARSHIP_LOG=error

# Homebrew (needs to be early in PATH)
if [[ "$DOT_TARGET" == "macos" ]]; then
  # macOS - hardcoded paths for speed
  export HOMEBREW_PREFIX="/opt/homebrew"
  export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
  export HOMEBREW_REPOSITORY="/opt/homebrew"
  export PATH="/opt/homebrew/bin:/opt/homebrew/sbin${PATH+:$PATH}"
  export MANPATH="/opt/homebrew/share/man${MANPATH+:$MANPATH}:"
  export INFOPATH="/opt/homebrew/share/info:${INFOPATH:-}"
elif [[ "$DOT_TARGET" == "linux" ]] && [[ -d /home/linuxbrew/.linuxbrew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Programming languages PATH setup
# Rust
[[ -d "$HOME/.cargo" ]] && export PATH="$HOME/.cargo/bin:$PATH"

# Go
export GOPATH="$HOME/go"
[[ -d "$GOPATH/bin" ]] && export PATH="$GOPATH/bin:$PATH"

# Ruby (via Homebrew)
if [[ -n "$HOMEBREW_PREFIX" ]] && [[ -d "$HOMEBREW_PREFIX/opt/ruby" ]]; then
  export PATH="$HOMEBREW_PREFIX/opt/ruby/bin:$PATH"
  export GEM_HOME="$HOME/.gem"
  export PATH="$GEM_HOME/bin:$PATH"
fi

# Ruby (via rbenv) - lazy loaded
if [[ -d "$HOME/.rbenv" ]]; then
  export RBENV_ROOT="$HOME/.rbenv"
  export PATH="$RBENV_ROOT/bin:$PATH"

  # Lazy-load rbenv init only when rbenv is called
  rbenv() {
    unfunction rbenv
    eval "$(command rbenv init - --no-rehash zsh)"
    rbenv "$@"
  }
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

# Editor configuration (KEEP LAST)
# Cache the result to avoid repeated command -v calls
if [[ -z "$EDITOR" ]]; then
  # Only do expensive lookups once per boot (cache in temp file)
  local editor_cache="/tmp/.zsh_editor_cache_${UID}"

  if [[ -f "$editor_cache" ]] && [[ -n "$(cat "$editor_cache" 2>/dev/null)" ]]; then
    # Use cached value
    export EDITOR="$(cat "$editor_cache")"
  else
    # Do the lookup and cache it
    if command -v nvim >/dev/null 2>&1; then
      export EDITOR="nvim"
    elif command -v code >/dev/null 2>&1; then
      export EDITOR="code"
    elif command -v vim >/dev/null 2>&1; then
      export EDITOR="vim"
    else
      export EDITOR="vi"
    fi
    echo "$EDITOR" > "$editor_cache"
  fi
fi

if [[ -z "$VISUAL" ]]; then
  command -v code >/dev/null 2>&1 && export VISUAL="code" || export VISUAL="$EDITOR"
fi

export GIT_EDITOR="$EDITOR"

# CLAUDE unlock phrase
export CLAUDE_GIT_PASSPHRASE='Avada Kedavra'

# Remove duplicate PATH entries
typeset -U PATH path

#-----------------------------------------------------------
# End of .zshenv
#-----------------------------------------------------------

