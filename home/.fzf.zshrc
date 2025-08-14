# Rose Pine Dawn FZF theme
export FZF_THEME_ROSE_PINE_DAWN='
  --color=hl:#907aa9,hl+:#d7827e,info:#56949f,marker:#ea9d34
  --color=prompt:#907aa9,spinner:#ea9d34,pointer:#d7827e,header:#b4637a
  --color=border:#dfdad9,label:#797593,query:#575279
  --color=bg+:#fffaf3,gutter:#faf4ed,selected-bg:#f2e9e1
  --border=rounded 
  --preview-window=border-rounded 
  --prompt="❯ " 
  --marker="●" 
  --pointer="▶" 
  --separator="─" 
  --scrollbar="│"
  --layout=reverse 
  --info=right
  --height=60%
  --multi
  --cycle
  --keep-right
  --ansi
  --tabstop=4
  --bind="ctrl-/:toggle-preview"
  --bind="ctrl-a:select-all"
  --bind="ctrl-d:deselect-all"
  --bind="ctrl-t:toggle-all"
  --bind="ctrl-y:execute-silent(echo -n {} | pbcopy)"
  --bind="ctrl-o:execute(code {})"
  --bind="alt-up:preview-page-up"
  --bind="alt-down:preview-page-down"
  --preview-window=right:50%:hidden
'

# Rose Pine Moon FZF theme
export FZF_THEME_ROSE_PINE_MOON='
  --color=hl:#c4a7e7,hl+:#ebbcba,info:#9ccfd8,marker:#f6c177
  --color=prompt:#c4a7e7,spinner:#f6c177,pointer:#ebbcba,header:#eb6f92
  --color=border:#403d52,label:#908caa,query:#e0def4
  --color=bg+:#2a273f,gutter:#232136,selected-bg:#393552
  --border=rounded 
  --preview-window=border-rounded 
  --prompt="❯ " 
  --marker="●" 
  --pointer="▶" 
  --separator="─" 
  --scrollbar="│"
  --layout=reverse 
  --info=right
  --height=60%
  --multi
  --cycle
  --keep-right
  --ansi
  --tabstop=4
  --bind="ctrl-/:toggle-preview"
  --bind="ctrl-a:select-all"
  --bind="ctrl-d:deselect-all"
  --bind="ctrl-t:toggle-all"
  --bind="ctrl-y:execute-silent(echo -n {} | pbcopy)"
  --bind="ctrl-o:execute(code {})"
  --bind="alt-up:preview-page-up"
  --bind="alt-down:preview-page-down"
  --preview-window=right:50%:hidden
'

# Rose Pine FZF theme (main)
export FZF_THEME_ROSE_PINE='
  --color=hl:#c4a7e7,hl+:#ebbcba,info:#9ccfd8,marker:#f6c177
  --color=prompt:#c4a7e7,spinner:#f6c177,pointer:#ebbcba,header:#eb6f92
  --color=border:#26233a,label:#908caa,query:#e0def4
  --color=bg+:#1f1d2e,gutter:#191724,selected-bg:#26233a
  --border=rounded 
  --preview-window=border-rounded 
  --prompt="❯ " 
  --marker="●" 
  --pointer="▶" 
  --separator="─" 
  --scrollbar="│"
  --layout=reverse 
  --info=right
  --height=60%
  --multi
  --cycle
  --keep-right
  --ansi
  --tabstop=4
  --bind="ctrl-/:toggle-preview"
  --bind="ctrl-a:select-all"
  --bind="ctrl-d:deselect-all"
  --bind="ctrl-t:toggle-all"
  --bind="ctrl-y:execute-silent(echo -n {} | pbcopy)"
  --bind="ctrl-o:execute(code {})"
  --bind="alt-up:preview-page-up"
  --bind="alt-down:preview-page-down"
  --preview-window=right:50%:hidden
'

# Set the active theme
export FZF_DEFAULT_OPTS=$FZF_THEME_ROSE_PINE_MOON

# Default command for FZF (when called directly)
export FZF_DEFAULT_COMMAND="fd --type f --strip-cwd-prefix --hidden --follow --exclude .git"

# File search (Ctrl+T)
export FZF_CTRL_T_OPTS="
  --preview 'bat --color=always --style=numbers --line-range=:500 {} 2>/dev/null || cat {} 2>/dev/null || echo \"[Preview unavailable]\"'
  --preview-window 'right:50%'
  --bind 'ctrl-/:toggle-preview'
  --bind 'ctrl-y:execute-silent(echo -n {} | pbcopy)'
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
export FZF_ALT_C_OPTS="
  --preview 'eza --tree --color=always {} 2>/dev/null || tree -C {} 2>/dev/null || ls -la {}'
  --preview-window 'right:50%'
  --bind 'ctrl-/:toggle-preview'
"
export FZF_ALT_C_COMMAND=$FZF_DEFAULT_COMMAND

# Theme switcher function
fzf_theme() {
    case "$1" in
        "dawn")
            export FZF_DEFAULT_OPTS=$FZF_THEME_ROSE_PINE_DAWN
            echo "Switched to Rose Pine Dawn theme"
            ;;
        "moon")
            export FZF_DEFAULT_OPTS=$FZF_THEME_ROSE_PINE_MOON
            echo "Switched to Rose Pine Moon theme"
            ;;
        "main"|"")
            export FZF_DEFAULT_OPTS=$FZF_THEME_ROSE_PINE
            echo "Switched to Rose Pine theme"
            ;;
        *)
            echo "Usage: fzf_theme [dawn|moon|main]"
            ;;
    esac
}
