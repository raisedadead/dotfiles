#-----------------------------------------------------------
# @raisedadead's config files
# Copyright: Mrugesh Mohapatra <https://mrugesh.dev>
# License: ISC
#
# File name: .zinit.zshrc
#-----------------------------------------------------------
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [ ! -d $ZINIT_HOME ]; then
    mkdir -p "$(dirname $ZINIT_HOME)"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "$ZINIT_HOME/zinit.zsh"

# autoload -Uz _zinit
# (( ${+_comps} )) && _comps[zinit]=_zinit

# Zinit's self-management and initial setup
zinit light zdharma-continuum/zinit

zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-completions

zinit light zdharma-continuum/fast-syntax-highlighting
zinit ice wait lucid pick"themes/catppuccin_mocha-zsh-syntax-highlighting.zsh"
zinit light catppuccin/zsh-syntax-highlighting

zinit light Aloxaf/fzf-tab

zinit light raisedadead/zsh-touchplus

zinit snippet OMZP::git
zinit snippet OMZP::sudo
