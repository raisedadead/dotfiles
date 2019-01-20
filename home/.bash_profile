#-----------------------------------------------------------
#
# @raisedadead's config files
# https://git.raisedadead.com/dotfiles
#
# Copyright: Mrugesh Mohapatra <https://raisedadead.com>
# License: ISC
#
# File name: .bash_profile
#
#-----------------------------------------------------------

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

# User specific environment and startup programs
PATH=$PATH:$HOME/.local/bin:$HOME/bin
export PATH="/usr/local/opt/mongodb@3.6/bin:$PATH"
