#-----------------------------------------------------------
# .bashrc configurations
#-----------------------------------------------------------

# setup for ubuntu and windows
_setup_ubuntu_windows()
{
    #-----------------------------
    # Homeshick
    #-----------------------------
    if [[ ! -d $HOME/.homesick ]]; then
        echo
        echo "Error: homeshick is not found or uninstalled."
        echo "Follow installation instructions on the repo:"
        echo "https://git.raisedadead.com/dotfiles"
        echo "Exiting..."
        echo
        return 1
    fi
    source $HOME/.homesick/repos/homeshick/homeshick.sh
    return 0
}

# setup for macOS
_setup_macos()
{
    echo
    echo "Todo: Setup is not implememted yet."
    echo "Not done a thing... exiting... bye."
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
        _setup_ubuntu_windows
    ;;
esac

#-----------------------------------------------------------
# Common configs
#-----------------------------------------------------------

#-----------------------------
# fzf
#-----------------------------
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

#-----------------------------------------------------------
