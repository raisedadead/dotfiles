ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "$ZINIT_HOME/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Zinit's self-management and initial setup
zinit light zdharma-continuum/zinit


### Custom plugins
GSO_ENABLE_KEYBINDINGS=true
zinit wait lucid for \
    raisedadead/zsh-touchplus \
    raisedadead/zsh-gso

### Node.js related plugins
NVM_AUTO_USE=true
zinit light lukechilds/zsh-nvm
zinit wait lucid for \
    lukechilds/zsh-better-npm-completion \
    g-plane/pnpm-shell-completion

### Files & directories
zinit light mfaerevaag/wd

### Git related plugins
zinit light z-shell/zsh-diff-so-fancy
zinit as"program" pick"bin/git-fuzzy" for bigH/git-fuzzy

### Syntax highlighting
zinit wait lucid for \
    zdharma-continuum/fast-syntax-highlighting \
    catppuccin/zsh-syntax-highlighting

### Vim mode
zinit light softmoth/zsh-vim-mode

### Docker
zinit wait lucid for \
    srijanshetty/docker-zsh

### Smart Input
zinit wait lucid for \
    raisedadead/zsh-smartinput

### zsh-users
zinit wait lucid for \
    zsh-users/zsh-autosuggestions \
    zsh-users/zsh-history-substring-search

### oh-my-zsh libraries
zinit snippet OMZ::lib/history.zsh
zinit snippet OMZ::lib/directories.zsh

### wakatime
zinit wait lucid for \
    sobolevn/wakatime-zsh-plugin

### Conditional loading for fzf
if can_haz fzf; then
    zinit wait lucid for \
        Aloxaf/fzf-tab
fi
