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
zinit wait lucid for \
    atclone"rm -rf /tmp/USE_CATPPUCCIN_THEME; touch /tmp/USE_CATPPUCCIN_THEME" \
    zdharma-continuum/fast-syntax-highlighting \
    as"null" \
    nocompile \
    if'[[ -f /tmp/USE_CATPPUCCIN_THEME ]]' \
    atload'fast-theme ${ZINIT[PLUGINS_DIR]}/catppuccin---zsh-fsh/themes/catppuccin-mocha.ini; echo; rm -rf /tmp/USE_CATPPUCCIN_THEME;' \
    catppuccin/zsh-fsh

### Completions and autosuggestions
zinit wait lucid for \
    blockf \
    zsh-users/zsh-completions \
    atload"!_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions

# General plugins
zinit light Aloxaf/fzf-tab
zinit light mfaerevaag/wd
zinit light softmoth/zsh-vim-mode

### My plugins
GSO_ENABLE_KEYBINDINGS=true
zinit wait lucid for \
    raisedadead/zsh-touchplus \
    raisedadead/zsh-gso \
    raisedadead/zsh-smartinput

### Node.js
NVM_AUTO_USE=true
zinit wait lucid for \
    lukechilds/zsh-nvm \
    lukechilds/zsh-better-npm-completion
zinit ice atload"zpcdreplay" atclone"./zplug.zsh" atpull"%atclone"
zinit light g-plane/pnpm-shell-completion

### Wakatime
zinit wait lucid for \
    sobolevn/wakatime-zsh-plugin

### Docker
zinit wait lucid for \
    srijanshetty/docker-zsh

### Snippets
zinit snippet OMZP::git
zinit snippet OMZP::sudo
