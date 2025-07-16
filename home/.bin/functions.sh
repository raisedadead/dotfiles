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

# load git functions
source ~/.bin/commit-past.sh

# load fzf functions
source ~/.bin/ssh-helpers.sh
source ~/.bin/file-search.sh

# load aws functions
source ~/.bin/ssh-ec2.sh

# terminal title
precmd() {print -Pn "\e]0;%~\a"}

# create convenient aliases for commonly used functions
alias git_commit_past='_mrgsh_gcp'           # commit with past date
alias ssh_host_select='_mrgsh_ssh'           # select ssh host from config
alias ssh_host_remove='_mrgsh_rkh'           # remove host from known_hosts
alias aws_ssh='_mrgsh_aws'                   # ssh to aws ec2 instance
alias aws_get_instance_id='_mrgsh_aws_get_id' # get ec2 instance id by name
alias fdd='_mrgsh_fdd'                       # find directories with fd
alias fdf='_mrgsh_fdf'                       # find files with fd
alias psf='_mrgsh_psf'                       # find processes with fzf
alias rgfzf='_mrgsh_rgfzf'                   # search file content with ripgrep+fzf
alias fif='_mrgsh_fif'                       # advanced file/content search
alias rkh='_mrgsh_rkh'                       # remove host from known_hosts

# completion descriptions
compdef '_describe "commit in the past" "(git_commit_past:\"commit with past date\")"' git_commit_past
compdef '_describe "select ssh host" "(ssh_host_select:\"select ssh host from config\")"' ssh_host_select
compdef '_describe "remove host" "(ssh_host_remove:\"remove host from known_hosts\")"' ssh_host_remove
compdef '_describe "aws ssh" "(aws_ssh:\"ssh to aws ec2 instance\")"' aws_ssh
compdef '_describe "get instance id" "(aws_get_instance_id:\"get ec2 instance id by name\")"' aws_get_instance_id
compdef '_describe "find directories" "(fdd:\"find directories with fd\")"' fdd
compdef '_describe "find files" "(fdf:\"find files with fd\")"' fdf
compdef '_describe "find processes" "(psf:\"find processes with fzf\")"' psf
compdef '_describe "search content" "(rgfzf:\"search file content with ripgrep+fzf\")"' rgfzf
compdef '_describe "advanced search" "(fif:\"advanced file/content search\")"' fif
compdef '_describe "remove host" "(rkh:\"remove host from known_hosts\")"' rkh

# load keybindings
source ~/.bin/keybindings.sh
