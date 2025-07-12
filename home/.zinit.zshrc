#-----------------------------------------------------------
# @raisedadead's config files
# Copyright: Mrugesh Mohapatra <https://mrugesh.dev>
# License: ISC
#
# File name: .zinit.zshrc
#-----------------------------------------------------------
### Setup
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [ ! -d $ZINIT_HOME ]; then
    mkdir -p "$(dirname $ZINIT_HOME)"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "$ZINIT_HOME/zinit.zsh"

### Zinit's self-management
zinit light zdharma-continuum/zinit

#### Plugins

### Syntax highlighting
zinit wait"0a" lucid for \
    atclone"rm -rf /tmp/USE_CATPPUCCIN_THEME; touch /tmp/USE_CATPPUCCIN_THEME" \
    zdharma-continuum/fast-syntax-highlighting \
    as"null" \
    nocompile \
    if'[[ -f /tmp/USE_CATPPUCCIN_THEME ]]' \
    atload'fast-theme ${ZINIT[PLUGINS_DIR]}/catppuccin---zsh-fsh/themes/catppuccin-mocha.ini; echo; rm -rf /tmp/USE_CATPPUCCIN_THEME;' \
    catppuccin/zsh-fsh

### Completions and autosuggestions
zinit wait"0b" lucid for \
    blockf \
    zsh-users/zsh-completions \
    atload"!_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions

# General plugins
zinit wait"1" lucid for \
    atload"zstyle ':fzf-tab:*' use-fzf-default-opts yes; zstyle ':fzf-tab:*' fzf-flags --height=~25%" \
    Aloxaf/fzf-tab

### My plugins
GSO_ENABLE_KEYBINDINGS=true
zinit wait"1" lucid for \
    raisedadead/zsh-touchplus \
    raisedadead/zsh-gso \
    raisedadead/zsh-smartinput \
    raisedadead/zsh-snr

### Node.js
NVM_AUTO_USE=true
zinit wait"1" lucid for \
    lukechilds/zsh-nvm \
    lukechilds/zsh-better-npm-completion
zinit ice wait"1" lucid atload"zpcdreplay" atclone"./zplug.zsh" atpull"%atclone"
zinit light g-plane/pnpm-shell-completion

### Wakatime
zinit wait"3" lucid for \
    sobolevn/wakatime-zsh-plugin

### Docker
zinit wait"1" lucid for \
    srijanshetty/docker-zsh

### VIM Mode
# zinit wait"1" lucid for \
#     jeffreytse/zsh-vi-mode
#
