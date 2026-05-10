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
# Fabric + MLX search/summarize stack
#-----------------------------
# Pipe targets — use $FABRIC_LOCAL by default (free, private, on-device)
can_haz fabric-ai && alias sum='fabric-ai -p summarize -m "$FABRIC_LOCAL"'
can_haz fabric-ai && alias wisdom='fabric-ai -p extract_wisdom -m "$FABRIC_LOCAL"'
can_haz fabric-ai && alias yt='fabric-ai -y'

# DDG search → summarize first hit with local Gemma
searchsum() {
  can_haz ddgr && can_haz jq && can_haz fabric-ai || { echo "needs ddgr+jq+fabric-ai"; return 1; }
  local url
  url=$(ddgr --np --json "$*" 2>/dev/null | jq -r '.[0].url') || return 1
  [[ -z "$url" || "$url" == "null" ]] && { echo "no result"; return 1; }
  echo "→ $url"
  fabric-ai -u "$url" -p summarize -m "$FABRIC_LOCAL"
}

# DDG search → extract_wisdom from top 3 hits
searchwisdom() {
  can_haz ddgr && can_haz jq && can_haz fabric-ai || { echo "needs ddgr+jq+fabric-ai"; return 1; }
  ddgr --np --json -n 3 "$*" 2>/dev/null | jq -r '.[].url' | while read -r url; do
    echo "=== $url ==="
    fabric-ai -u "$url" -p extract_wisdom -m "$FABRIC_LOCAL"
  done
}

# MLX server lifecycle (process-compose foreground)
if can_haz process-compose && [[ -f "$HOME/.config/mlx/process-compose.yaml" ]]; then
  alias mlx-up='process-compose --config "$HOME/.config/mlx/process-compose.yaml" up'
  alias mlx-up-bg='process-compose --config "$HOME/.config/mlx/process-compose.yaml" up --tui=false --detached-with-logs'
  alias mlx-down='process-compose --config "$HOME/.config/mlx/process-compose.yaml" down'
fi
# Quick liveness check — no daemon poke required
alias mlx-status='curl -sf http://127.0.0.1:8080/v1/models >/dev/null && echo "mlx: up" || echo "mlx: down"'
# Pull a model into the HF cache: `mlx-pull mlx-community/gemma-4-e4b-it-4bit`
mlx-pull() {
  can_haz hf || { echo "needs hf cli"; return 1; }
  [[ -z "$1" ]] && { echo "usage: mlx-pull <hf-repo-id>"; return 1; }
  hf download "$1"
}


