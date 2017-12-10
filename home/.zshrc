##############################
# Zplug
##############################
# Check if zplug is installed
if [[ ! -d ~/.zplug ]]; then
  git clone https://github.com/zplug/zplug ~/.zplug
  source ~/.zplug/init.zsh && zplug update --self
fi

# Essential
source ~/.zplug/init.zsh

zplug 'zplug/zplug', hook-build:'zplug --self-manage'
zplug "b4b4r07/enhancd", use:init.sh

zplug "plugins/git", from:oh-my-zsh
zplug "caarlos0/git-add-remote"

zplug "zsh-users/zsh-history-substring-search"
zplug "zdharma/fast-syntax-highlighting"
zplug "zsh-users/zsh-completions"
autoload -U compinit && compinit

# zplug 'dracula/zsh', as:theme
zplug "mafredri/zsh-async", from:github
zplug "sindresorhus/pure", use:pure.zsh, from:github, as:theme
zplug "tysonwolker/iterm-tab-colors"

# Install plugins if there are plugins that have not been installed
if ! zplug check --verbose; then
    printf "Install? [y/N]: "
    if read -q; then
        echo; zplug install
    fi
fi

# Then, source plugins and add commands to $PATH
# zplug load --verbose
zplug load

##############################
# Brewfile
##############################
export PATH="/usr/local/bin:/usr/local/sbin:~/bin:$PATH"
if [ -f $(brew --prefix)/etc/brew-wrap ];then
  source $(brew --prefix)/etc/brew-wrap
fi

##############################
# nvm
##############################
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

##############################
# aliases
##############################
source ~/.alias

##############################
# homeshick
#############################
export HOMESHICK_DIR=/usr/local/opt/homeshick
source "/usr/local/opt/homeshick/homeshick.sh"
fpath=($HOME/.homesick/repos/homeshick/completions $fpath)

##############################
# fzf
##############################
[ -f ~/.bin/.fzf.zsh ] && source ~/.bin/.fzf.zsh
