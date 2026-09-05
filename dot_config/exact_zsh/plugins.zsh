_mrgsh_zsh_plugins_install() {
  emulate -L zsh
  local repo revision directory staging
  mkdir -p -- "$ZPLUGDIR" || return
  while read -r repo revision; do
    [[ -n $repo ]] || continue
    directory=$ZPLUGDIR/${repo:t}
    [[ -d $directory ]] && continue
    staging=$(mktemp -d "$ZPLUGDIR/.install.XXXXXXXX") || return
    if git -C "$staging" init -q &&
      git -C "$staging" remote add origin "https://github.com/$repo" &&
      git -C "$staging" fetch -q --depth=1 origin "$revision" &&
      git -C "$staging" checkout -q --detach FETCH_HEAD; then
      mv -- "$staging" "$directory" || return
    else
      print -u2 -- "Plugin install failed: $repo ($staging)"
      return 1
    fi
  done < "$ZDOTDIR/plugins.lock"
}

_mrgsh_zsh_plugins_sync() {
  emulate -L zsh
  local lock=$1 stamp=$ZPLUGDIR/.plugins.lock repo revision directory previous dirty
  [[ -r $stamp && "$(<$stamp)" == "$(<$lock)" ]] && return 0
  local -a directories revisions previous_revisions
  while read -r repo revision; do
    [[ -n $repo ]] || continue
    directory=$ZPLUGDIR/${repo:t}
    dirty=$(git -C "$directory" status --porcelain --untracked-files=no) || return
    if [[ -n $dirty ]]; then
      print -u2 -- "Plugin has local changes: $repo"
      return 1
    fi
    previous=$(git -C "$directory" rev-parse HEAD) || return
    [[ $previous == "$revision" ]] && continue
    git -C "$directory" cat-file -e "$revision^{commit}" 2>/dev/null ||
      git -C "$directory" fetch -q --depth=1 origin "$revision" || return
    directories+=("$directory")
    revisions+=("$revision")
    previous_revisions+=("$previous")
  done < "$lock"
  local -i index rollback
  for (( index=1; index <= $#directories; index++ )); do
    if ! git -C "$directories[index]" checkout -q --detach "$revisions[index]"; then
      for (( rollback=index-1; rollback >= 1; rollback-- )); do
        git -C "$directories[rollback]" checkout -q --detach "$previous_revisions[rollback]" ||
          print -u2 -- "Plugin rollback failed: $directories[rollback]"
      done
      return 1
    fi
  done
  cp -- "$lock" "$stamp"
}

_mrgsh_zsh_pnpm_helper() {
  emulate -L zsh
  local repo revision stamp=$ZPLUGDIR/.pnpm-helper-revision
  while read -r repo revision; do
    [[ ${repo:t} == pnpm-shell-completion ]] || continue
    if [[ -x "$ZPLUGDIR/pnpm-shell-completion/pnpm-shell-completion" &&
      -r $stamp && "$(<$stamp)" == "$revision" ]]; then
      return 0
    fi
    (builtin cd -q -- "$ZPLUGDIR/pnpm-shell-completion" && ./zplug.zsh) || return
    print -r -- "$revision" > "$stamp"
    return
  done < "$ZDOTDIR/plugins.lock"
}

zsh-plugin-update() {
  emulate -L zsh
  local repo revision directory new_revision dirty lock
  lock=$(mktemp "$ZPLUGDIR/.update.XXXXXXXX") || return
  {
    while read -r repo revision; do
      [[ -n $repo ]] || continue
      directory=$ZPLUGDIR/${repo:t}
      dirty=$(git -C "$directory" status --porcelain --untracked-files=no) || return
      if [[ -n $dirty ]]; then
        print -u2 -- "Plugin has local changes: $repo"
        return 1
      fi
      git -C "$directory" fetch --depth=1 origin HEAD || return
      new_revision=$(git -C "$directory" rev-parse FETCH_HEAD) || return
      print -r -- "$repo $new_revision" >> "$lock"
    done < "$ZDOTDIR/plugins.lock"
    _mrgsh_zsh_plugins_sync "$lock" || return
    cp -- "$lock" "$ZDOTDIR/plugins.lock" || return
    _mrgsh_zsh_pnpm_helper || return
    rebuild-completions || return
    print -- 'Plugin revisions updated. Open a new shell, then capture ~/.config/zsh/plugins.lock.'
  } always {
    rm -f -- "$lock"
  }
}

if _mrgsh_zsh_plugins_install && _mrgsh_zsh_plugins_sync "$ZDOTDIR/plugins.lock"; then
  _mrgsh_zsh_pnpm_helper
fi
