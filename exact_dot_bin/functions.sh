#!/usr/bin/env zsh

#-----------------------------------------------------------
#
# @raisedadead's config files
# Copyright: Mrugesh Mohapatra <https://mrugesh.dev>
# License: ISC
#
# File name: functions.sh
#
#-----------------------------------------------------------

# source utilities
source ~/.bin/utils.sh
source ~/.bin/cleanup.sh

# load git functions
source ~/.bin/commit-past.sh

# load ssh helpers
source ~/.bin/ssh-helpers.sh

# load search functions
source ~/.bin/fnm.sh
source ~/.bin/awake.sh

# terminal title (disabled — was overwriting oh-my-posh's precmd)
# _set_terminal_title() { print -Pn "\e]0;%~\a" }
# autoload -Uz add-zsh-hook
# add-zsh-hook precmd _set_terminal_title

# create convenient aliases for commonly used functions
alias git_commit_past='_mrgsh_gcp'             # commit with past date
alias ssh_host_select='_mrgsh_ssh'             # select ssh host from config
alias ssh_host_remove='_mrgsh_rkh'             # remove host from known_hosts
alias rkh='_mrgsh_rkh'                         # remove host from known_hosts
alias cleanup='_mrgsh_cleanup'                 # cleanup macOS junk files
alias set_default_app='_mrgsh_set_default_app' # set default app for dev files
alias node_globals='_mrgsh_node_globals'
alias node_use='_mrgsh_fnm_use'
alias node_default='_mrgsh_fnm_default'
alias node_rm='_mrgsh_fnm_rm'
alias node_install='_mrgsh_fnm_install'

# completion descriptions
compdef '_describe "commit in the past" "(git_commit_past:\"commit with past date\")"' git_commit_past
compdef '_describe "select ssh host" "(ssh_host_select:\"select ssh host from config\")"' ssh_host_select
compdef '_describe "remove host" "(ssh_host_remove:\"remove host from known_hosts\")"' ssh_host_remove
compdef '_describe "remove host" "(rkh:\"remove host from known_hosts\")"' rkh
compdef '_describe "cleanup junk" "(cleanup:\"cleanup macOS junk files\")"' cleanup
compdef '_describe "set default app" "(set_default_app:\"set default app for dev files\")"' set_default_app
