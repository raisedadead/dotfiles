#-----------------------------------------------------------
# .bashrc configurations
#-----------------------------------------------------------

# setup for work
function _setup_work(){
    #-----------------------------
    # Homeshick
    #-----------------------------
    if [[ ! -d $HOME/.homesick ]]; then
        git clone git://github.com/andsens/homeshick.git $HOME/.homesick/repos/homeshick
        echo ">>>>>> homeshick was just freshly installed. <<<<<<<"
    fi
 
    source $HOME/.homesick/repos/homeshick/homeshick.sh
    return 0
}

# setup for home
function _setup_home(){
    echo "Todo: Setup is not implememted yet."
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
        _setup_home
    ;;
    windows* | linux*)
        _setup_work
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
