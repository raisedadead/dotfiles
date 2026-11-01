[[ $TERM_PROGRAM == rex && -n $REX_SESSION && -z $TMUX ]] || return 0
zmodload zsh/datetime zsh/parameter
autoload -Uz add-zsh-hook

typeset -gi REX_STATUS_MIN=${REX_STATUS_MIN:-15}
typeset -ga REX_STATUS_SKIP=(
  nvim vim vi nano w3m lnav fx mo spf keys cdi _mrgsh_ssh _mrgsh_rkh
  top htop btop btm k9s gdu watch lazygit tig fzf ssh mosh tmux rex psql sqlite3
  ca fg bg wait 'wt switch'
  'git merge' 'git tag' 'git revert' 'git cherry-pick'
  'git mergetool' 'git difftool' 'git rebase -i' 'git rebase --interactive'
  'git add -p' 'git add -i' 'git add -e' 'git add --patch' 'git add --interactive'
  'gh dash' 'gh pr create' 'gh pr view' 'gh pr diff' 'gh pr edit' 'gh pr review'
  'gh pr merge' 'gh pr comment' 'gh issue create' 'gh issue view' 'gh issue edit'
  'gh issue comment' 'gh auth login' 'gh repo create'
  'docker exec' 'docker attach' 'docker run -i' 'docker run -t' 'docker run --interactive'
)
typeset -ga REX_STATUS_PAGER=(
  less more man delta bat glow mdr
  'git log' 'git diff' 'git show' 'git blame' 'git grep' 'git reflog' 'git shortlog'
  'git help' 'git stash show'
)
typeset -ga REX_STATUS_REPL=(zsh bash sh node bun python python3 lua luajit irb ruby)
typeset -ga REX_STATUS_AGENTS=(claude codex pi opencode)
typeset -ga _rex_prefix=(
  command builtin exec noglob nocorrect nohup nice env sudo caffeinate time -
  '!' '(' ')' '{' '}' if then else elif fi do done while until coproc
)
typeset -ga _rex_argopts=(
  'exec -a' 'nice -n' 'env -u' 'env -P' 'caffeinate -t' 'caffeinate -w'
  'sudo -u' 'sudo -g' 'sudo -C' 'sudo -D' 'sudo -p' 'sudo -U' 'git -c' 'git -C'
)
typeset -g _rex_cmd= _rex_t0=
typeset -gi _rex_sent=0

_rex_preexec() {
  if (( _rex_sent )); then
    printf '\e]7501;state=clear\e\\'
    _rex_sent=0
  fi
  _rex_cmd=$3
  _rex_t0=$EPOCHREALTIME
}

_rex_takes() {
  (( ${_rex_argopts[(Ie)$1 $2]} )) && return 0
  [[ $2 == -[^-]?* ]] && (( ${_rex_argopts[(Ie)$1 -${2[-1]}]} ))
}

_rex_redirect() {
  [[ $1 == ([0-9]#|\&)[\<\>]* ]] || return 1
  [[ $1 == *\(* ]] && return 0
  n=2
  [[ $1 == (|0)\<* ]] && fed=1
  return 0
}

_rex_segment() {
  prog= fed= pos=() flags=()
  local wrap= opts=1
  local -i n
  while (( $# )); do
    n=1
    if (( ${_rex_prefix[(Ie)$1]} )); then
      wrap=$1
    elif [[ $1 == [A-Za-z_][A-Za-z0-9_]#=* ]] || _rex_redirect $1; then
      :
    elif [[ -n $wrap && $1 == -* ]]; then
      [[ $1 == -- ]] && wrap=
      _rex_takes $wrap $1 && n=2
    else
      break
    fi
    shift $(( n < $# ? n : $# ))
  done
  [[ $# -gt 0 && $1 != (for|foreach|select|case|function|'[['|'(('*) ]] || return 0
  prog=${${(Q)1}:t}
  shift
  while (( $# && $#pos < 3 )); do
    n=1
    if [[ -n $opts && $1 == -- ]]; then
      opts=
    elif _rex_redirect $1; then
      :
    elif [[ -n $opts && $1 == -?* ]]; then
      flags+=($1)
      _rex_takes $prog $1 && n=2
    else
      pos+=(${(Q)1})
    fi
    shift $(( n < $# ? n : $# ))
  done
}

_rex_listed() {
  local entry w
  local -a ew
  local -i n
  for entry; do
    ew=(${=entry})
    [[ $ew[1] == "$prog" ]] || continue
    n=0
    for w in $ew[2,-1]; do
      if [[ $w == --* ]]; then
        (( ${flags[(Ie)$w]} )) || continue 2
      elif [[ $w == -? ]]; then
        [[ -n ${flags[(r)-[^-]#${w#-}*]} ]] || continue 2
      else
        [[ ${pos[++n]} == "$w" ]] || continue 2
      fi
    done
    return 0
  done
  return 1
}

_rex_skips() {
  [[ $prog == %* ]] && return 0
  (( ! $#pos )) && [[ -n $head && -z $fed ]] && (( ${REX_STATUS_REPL[(Ie)$prog]} )) &&
    return 0
  _rex_listed $REX_STATUS_SKIP && return 0
  [[ -n $last ]] && _rex_listed $REX_STATUS_PAGER && return 0
  if [[ $prog == git && $pos[1] == commit ]]; then
    [[ -n ${flags[(r)--fixup=(amend|reword):*]} ]] && return 0
    local keep='(-[^-]#[mFC]*|--(message|file|reuse-message|no-edit|fixup)(|=*))'
    [[ -z ${flags[(r)$~keep]} ]] && return 0
  fi
  [[ -z $1 && $prog == git && -n $pos[1] ]] || return 1
  local def
  def=$(command git config --get "alias.$pos[1]" 2>/dev/null) || return 1
  [[ $def != \!* ]] || return 1
  _rex_segment git ${(z)def}
  _rex_skips resolved
}

_rex_precmd() {
  local -i code=$?
  emulate -L zsh -o extended_glob
  local cmd=$_rex_cmd t0=$_rex_t0
  _rex_cmd= _rex_t0=
  [[ -n $t0 ]] || return 0
  (( code > 128 )) && [[ $signals[code-127] == (INT|QUIT|PIPE|TSTP|STOP|TTIN|TTOU) ]] && return 0
  local -i secs=$(( EPOCHREALTIME - t0 ))
  (( secs >= REX_STATUS_MIN )) || return 0
  local line w prev
  local -a kept docs
  for line in "${(@f)cmd}"; do
    if (( $#docs )); then
      [[ $docs[1] == *- ]] && line=${line##$'\t'#}
      [[ $line == "$docs[2]" ]] && docs[1,2]=()
      continue
    fi
    kept+=($line)
    prev=
    for w in ${(z)line}; do
      [[ $prev == ([0-9]#)\<\<(|-) ]] && docs+=($prev ${(Q)w})
      prev=$w
    done
  done
  local prog fed app first head=1 last
  local -a seg pos flags words=(${(z)${(F)kept}} ';')
  for w in $words; do
    if [[ $w != (\;|\;\;|\;\&|\;\||\&\&|\|\||\||\|\&|\&|\&!|\&\|) ]]; then
      seg+=($w)
      continue
    fi
    (( ${#${(@Q)seg}:*REX_STATUS_AGENTS} )) && return 0
    _rex_segment $seg
    seg=()
    [[ $w == (\||\|\&) ]] && last= || last=1
    if [[ -n $prog ]]; then
      _rex_skips && return 0
      if [[ -n $head ]]; then
        app=$prog
        (( $+builtins[$prog] || $+functions[$prog] )) || first=${first:-$prog}
      fi
    fi
    head=$last
  done
  local name=${${${first:-$app}//[[:cntrl:]]/}[1,64]}
  [[ -n $name ]] || return 0
  local id=${${name//[^A-Za-z0-9_.+-]/}[1,32]}
  local dur=$(( secs % 60 ))s
  (( secs >= 60 )) && dur="$(( secs / 60 % 60 ))m $dur"
  (( secs >= 3600 )) && dur="$(( secs / 3600 ))h $dur"
  local report="state=done"
  (( code )) && report="state=error"
  [[ -n $id ]] && report+=":app=$id"
  printf '\e]7501;%s:msg=%s\e\\' "$report" \
    "$(print -rn -- "$name: exit $code after $dur" | base64 | tr -d '\n')"
  _rex_sent=1
}

add-zsh-hook preexec _rex_preexec
add-zsh-hook precmd _rex_precmd
