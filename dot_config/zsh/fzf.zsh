# Catppuccin Mocha FZF theme
export FZF_THEME_CATPPUCCIN_MOCHA='
  --color=bg+:#313244,bg:#1E1E2E,spinner:#F5E0DC,hl:#F38BA8
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
export FD_COMMON_OPTS="--follow --hidden --color=always --exclude .git --exclude node_modules --exclude .venv --no-ignore-vcs"
export EZA_TREE_COMMAND='eza --tree --recurse --level 3 --only-dirs --icons --color=always'

# FZF Default Options (may be used by other tools using FZF)
export FZF_DEFAULT_OPTS="$FZF_BASE_OPTS $FZF_THEME"

# Default command for FZF (when called directly)
export FZF_DEFAULT_COMMAND="fd --type f --strip-cwd-prefix $FD_COMMON_OPTS"

# File search (Ctrl+T)
export FZF_CTRL_T_OPTS="$FZF_BASE_OPTS $FZF_THEME
  --height=70%
  --preview-window=border-rounded:right:50%
  --preview 'bat --color=always --style=numbers --line-range=:500 {} 2>/dev/null || cat {} 2>/dev/null || echo \"[Preview unavailable]\"'
  --bind 'ctrl-/:toggle-preview'
  --bind 'ctrl-y:execute-silent(echo -n {} | pbcopy)'
  --bind 'shift-up:preview-half-page-up'
  --bind 'shift-down:preview-half-page-down'
"
export FZF_CTRL_T_COMMAND=$FZF_DEFAULT_COMMAND


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
