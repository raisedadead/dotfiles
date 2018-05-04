# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

# User specific environment and startup programs

PATH=$PATH:$HOME/.local/bin:$HOME/bin

export PATH
[ -d $HOME/.nvm ] && source $HOME/.nvm/nvm.sh

export PATH="/usr/local/opt/node@8/bin:$PATH"
