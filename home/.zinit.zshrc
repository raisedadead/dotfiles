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

### Plugins
zinit wait lucid for \
    atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay" \
    zdharma-continuum/fast-syntax-highlighting \
    blockf \
    zsh-users/zsh-completions \
    atload"!_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions
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
