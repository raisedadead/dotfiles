# Catppuccin Mocha FZF theme
export FZF_THEME_CATPPUCCIN_MOCHA='
  --color=bg+:#313244,bg:#11111B,spinner:#F5E0DC,hl:#F38BA8
  --color=fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC
  --color=marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8
  --color=selected-bg:#45475A
  --color=border:#6C7086,label:#CDD6F4
'

# Rose Pine Moon FZF theme
export FZF_THEME_ROSE_PINE_MOON='
  --color=hl:#c4a7e7,hl+:#ebbcba,info:#9ccfd8,marker:#f6c177
  --color=prompt:#c4a7e7,spinner:#f6c177,pointer:#ebbcba,header:#eb6f92
  --color=border:#403d52,label:#908caa,query:#e0def4
  --color=bg+:#2a273f,gutter:#232136,selected-bg:#393552
'

export FZF_THEME=$FZF_THEME_CATPPUCCIN_MOCHA

# FZF Base Options
export FZF_BASE_OPTS='
  --border=rounded
  --prompt="❯ "
  --marker="●"
  --pointer="▶"
  --separator="─"
  --scrollbar="│"
  --layout=reverse
  --keep-right
  --info=right
  --ansi
  --height=60%
'

# Common fd options
export FD_COMMON_OPTS="--follow --hidden --color=always --exclude .git --exclude node_modules --exclude .venv"
export EZA_TREE_COMMAND='eza --tree --recurse --level 3 --only-dirs --icons --color=always'

# FZF Default Options (may be used by other tools using FZF)
export FZF_DEFAULT_OPTS="$FZF_BASE_OPTS $FZF_THEME"

# Default command for FZF (when called directly)
export FZF_DEFAULT_COMMAND="fd --type f --strip-cwd-prefix $FD_COMMON_OPTS"

# File search (Ctrl+T)
export FZF_CTRL_T_COMMAND="fd --type f --type d --strip-cwd-prefix $FD_COMMON_OPTS --color=never --print0"
export FZF_CTRL_T_OPTS="$FZF_BASE_OPTS $FZF_THEME
  --height=70%
  --border-label=' Files '
  --preview-window=border-rounded:right:50%
  --preview 'if [ -d {} ]; then eza --tree --level=2 --icons --color=always -- {}; elif [ \"\$(file --brief --mime-encoding -- {})\" = binary ]; then file --brief -- {}; else bat --color=always --style=numbers --line-range=:500 -- {}; fi'
  --bind 'ctrl-/:toggle-preview'
  --bind 'ctrl-y:execute-silent(printf %s {} | pbcopy)'
  --bind 'ctrl-g:reload($FZF_CTRL_T_COMMAND --no-ignore-vcs)+change-border-label( Files + ignored )'
  --bind 'shift-up:preview-half-page-up'
  --bind 'shift-down:preview-half-page-down'
"

_mrgsh_fzf_file_select() (
  emulate -L zsh
  builtin cd -q -- "$1" || return
  FZF_DEFAULT_COMMAND=$FZF_CTRL_T_COMMAND \
  FZF_DEFAULT_OPTS=$(__fzf_defaults '--reverse --scheme=path' "${FZF_CTRL_T_OPTS-} -m") \
  FZF_DEFAULT_OPTS_FILE='' \
    $(__fzfcmd) --read0 --print0 --query "$2" < /dev/tty
)

# https://github.com/junegunn/fzf/issues/4656
_mrgsh_fzf_file_widget() {
  emulate -L zsh
  setopt extended_glob
  local -a reply selections
  local REPLY REPLY2 left=$LBUFFER right=$RBUFFER typed='' decoded root query='' selection item replacement=''
  local -i word_index use_tilde=0
  autoload -Uz split-shell-arguments
  split-shell-arguments
  word_index=$REPLY
  if (( word_index % 2 && word_index > 1 && CURSOR == ${(cj..)#reply[1,word_index-1]} )); then
    (( word_index-- ))
  fi
  case $reply[word_index] in
    [0-9]#[\<\>]*|\{[[:alnum:]_]##\}[\<\>]*|'&>'*|';'|';;'|';;&'|';&'|'&'|'&!'|'&|'|'&&'|'|'|'||'|'|&'|'('|')')
      if (( word_index > 2 && CURSOR == ${(cj..)#reply[1,word_index-1]} )) && [[ -z $reply[word_index-1] ]]; then
        (( word_index -= 2 ))
      else
        return 0
      fi
      ;;
  esac
  if [[ $reply[word_index] == \{[[:alnum:]_]##\} &&
    -z $reply[word_index+1] && $reply[word_index+2] == [\<\>]* ]]; then
    return 0
  fi
  if (( word_index % 2 == 0 )); then
    left=${(j..)reply[1,word_index-1]}
    right=${(j..)reply[word_index+1,-1]}
    typed=${reply[word_index][1,CURSOR-${#left}]}
  fi
  decoded=${(Q)typed}
  if [[ $decoded == "$typed" && ( $typed[1] == \" || $typed[1] == \' ) ]]; then
    typed+=$typed[1]
    decoded=${(Q)typed}
  fi
  if [[ $typed == '~' || $typed == '~/'* ]]; then
    decoded=$HOME${decoded#'~'}
    use_tilde=1
  fi
  root=${decoded:-.}
  while [[ ! -d $root ]]; do
    query=${root:t}${query:+/$query}
    if [[ $root != */* ]]; then
      root=.
      break
    fi
    root=${root:h}
  done
  selection=$(_mrgsh_fzf_file_select "$root" "$query")
  local ret=$?
  if (( ret )); then
    zle redisplay
    return $ret
  fi
  selections=("${(@0)selection}")
  for item in "${selections[@]}"; do
    [[ -n $item ]] || continue
    if [[ $root != . || $decoded == ./* ]]; then
      item=${root%/}/$item
    fi
    if (( use_tilde )) && [[ $item == "$HOME/"* ]]; then
      item=\~/${(q)${item#"$HOME/"}}
    else
      item=${(q)item}
    fi
    replacement+="${replacement:+ }$item"
  done
  [[ -n $replacement ]] || return 0
  [[ -n $right ]] || replacement+=' '
  LBUFFER=$left$replacement
  RBUFFER=$right
  zle reset-prompt
}

(( $+functions[__fzfcmd] )) && zle -N fzf-file-widget _mrgsh_fzf_file_widget


# Command history (Ctrl+R) - Commented out since using Atuin
# export FZF_CTRL_R_OPTS="
#   --preview 'echo {}'
#   --preview-window 'down:3:hidden:wrap'
#   --bind 'ctrl-/:toggle-preview'
#   --bind 'ctrl-y:execute-silent(echo -n {} | pbcopy)'
#   --color header:italic
#   --header 'Press CTRL-Y to copy command into clipboard'
# "

# Directory navigation (Alt+C)
export FZF_ALT_C_OPTS="$FZF_BASE_OPTS $FZF_THEME
  --height=70%
  --preview-window=border-rounded:right:50%
  --preview '$EZA_TREE_COMMAND {} 2>/dev/null || eza --tree --color=always {} 2>/dev/null || tree -C {} 2>/dev/null || ls -la {}'
  --bind 'ctrl-/:toggle-preview'
  --bind 'shift-up:preview-half-page-up'
  --bind 'shift-down:preview-half-page-down'
"
export FZF_ALT_C_COMMAND="fd --type d --strip-cwd-prefix $FD_COMMON_OPTS"
