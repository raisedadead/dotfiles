_mrgsh_completion_init() {
  emulate -L zsh
  zmodload zsh/stat || return
  local directory signature=$ZSH_VERSION state=${XDG_CACHE_HOME:-$HOME/.cache}/zsh/completion-state
  local -A metadata
  local -a entries
  local -a stale=( ~/.zcompdump(N.mh+24) )
  for directory in $fpath; do
    if zstat -H metadata -- "$directory" 2>/dev/null; then
      entries=("$directory"/*(N:t))
      signature+=$'\n'"$directory:$metadata[inode]:$metadata[mtime]:${(j:,:)entries}"
    else
      signature+=$'\n'"$directory:missing"
    fi
  done
  autoload -Uz compinit
  if [[ $1 == rebuild || ! -r $state || ! -r ~/.zcompdump || "$(<$state)" != "$signature" ]] || (( $#stale )); then
    rm -f -- ~/.zcompdump
    compinit -d ~/.zcompdump || return
    mkdir -p -- "${state:h}" || return
    print -r -- "$signature" > "$state"
  else
    compinit -C -d ~/.zcompdump
  fi
}

rebuild-completions() { _mrgsh_completion_init rebuild }

update-completions() {
  emulate -L zsh
  setopt pipefail
  local tool temporary
  mkdir -p ~/.zfunc || return
  for tool in gh op wrangler; do
    can_haz "$tool" || continue
    temporary=$(mktemp "$HOME/.zfunc/.completion.XXXXXXXX") || return
    case $tool in
      gh) gh completion -s zsh > "$temporary" ;;
      op) op completion zsh > "$temporary" ;;
      wrangler) wrangler complete zsh | sed -n '/^#compdef/,$p' > "$temporary" ;;
    esac
    if (( $? )) || [[ ! -s $temporary ]]; then
      rm -f -- "$temporary"
      print -u2 -- "Completion generation failed: $tool"
      return 1
    fi
    mv -- "$temporary" "$HOME/.zfunc/_$tool" || return
  done
  typeset -U fpath
  fpath=("$HOME/.zfunc" $fpath)
  rebuild-completions
}

_mrgsh_completion_init
zstyle ':completion:*:chezmoi:*' file-patterns '*(D):all-files'
