#-----------------------------------------------------------
#
# @raisedadead's config files
# https://get.ms/dotfiles
#
# Copyright: Mrugesh Mohapatra <https://mrugesh.dev>
# License: ISC
#
# File name: .bashrc
#
#-----------------------------------------------------------

# setup for linux and windows
_setup_linux_windows()
{
    #-----------------------------
    # Homeshick
    #-----------------------------
    if [[ ! -d ~/.homesick ]]; then
        echo
        echo "Error: homeshick is not found or uninstalled."
        echo "Follow installation instructions on the repo:"
        echo "https://get.ms/dotfiles"
        echo "Exiting..."
        echo
        return 1
    fi
    source ~/.homesick/repos/homeshick/homeshick.sh
    source ~/.homesick/repos/homeshick/completions/homeshick-completion.bash
    return 0
}

# setup for macOS
_setup_macos()
{
    echo
    echo "Looked for a bash setup and found none."
    echo "Did you forget you use ZSH on macOS ?!!"
    echo
    return 1
}

# Check and load the utils before proceeding further
if [[ ! -d ~/.bin || ! -f ~/.bin/utils.sh ]]; then
    echo "Cannot find bin or bin/utils. Check ~/.bashrc where this error is."
    return 1
fi
# Load the utils and set the installation environment
source ~/.bin/utils.sh && TARGET=$( _get_system )

case "$TARGET" in
    macos*)
        _setup_macos
    ;;
    windows* | linux*)
        _setup_linux_windows
    ;;
esac

#-----------------------------------------------------------
# Common configs
#-----------------------------------------------------------

#-----------------------------
# fzf
#-----------------------------
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

#-----------------------------
# aliases
#-----------------------------
[ -f ~/.alias ] && source ~/.alias

#-----------------------------
# hub
#-----------------------------
[ -d ~/hub ] && export PATH=$PATH:~/hub/bin


#-----------------------------
# linuxbrew
#-----------------------------
[ -d /home/linuxbrew ] && eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)

#-----------------------------
# Path settings
#-----------------------------

export PATH="$PATH:~/.local/bin:~/bin"

#-----------------------------
# NVM
#-----------------------------

export NVM_DIR="~/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

#-----------------------------------------------------------

# Warning: Everything below this line was probably added automatically.
