zmodload zsh/datetime
autoload -Uz add-zsh-hook

typeset -gi REX_STATUS_MIN=${REX_STATUS_MIN:-15}
typeset -ga REX_STATUS_SKIP=(
  nvim vim vi less more man top htop btop lazygit tig fzf ssh mosh tmux rex
  claude codex pi opencode mdr glow bat watch
)
typeset -g _rex_cmd= _rex_t0=

_rex_preexec() {
  _rex_cmd=$1
  _rex_t0=$EPOCHREALTIME
}

_rex_precmd() {
  local -i code=$?
  local cmd=$_rex_cmd t0=$_rex_t0
  _rex_cmd= _rex_t0=
  [[ -n $t0 ]] || return 0
  local -i secs=$(( EPOCHREALTIME - t0 ))
  (( secs >= REX_STATUS_MIN )) || return 0
  local -a words=(${(z)cmd})
  while [[ ${words[1]} == *=* || ${words[1]} == (command|builtin|exec|time|nice) ]]; do
    shift words
  done
  local prog=${words[1]:t}
  (( ${REX_STATUS_SKIP[(Ie)$prog]} )) && return 0
  local state=done
  (( code )) && state=error
  local app=${prog//[^A-Za-z0-9_.,+\/=-]/}
  local msg="${cmd[1,120]}: exit $code after ${secs}s"
  printf '\e]7501;state=%s:app=%s:msg=%s\e\\' \
    $state ${app[1,32]} "$(print -rn -- $msg | base64 | tr -d '\n')"
}

add-zsh-hook preexec _rex_preexec
add-zsh-hook precmd _rex_precmd
