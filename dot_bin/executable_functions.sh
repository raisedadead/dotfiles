
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
source ~/.bin/search.sh

# yazi wrapper: q to cd on exit, Q to quit in place
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
	command yazi "$@" --cwd-file="$tmp"
	local cwd
	IFS= read -r -d '' cwd < "$tmp"
	[ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}

# terminal title (disabled — was overwriting oh-my-posh's precmd)
# _set_terminal_title() { print -Pn "\e]0;%~\a" }
# autoload -Uz add-zsh-hook
# add-zsh-hook precmd _set_terminal_title

home() {
  if [[ "$1" == "cd" ]]; then
    case "${2:-}" in
      public|pub)   builtin cd -- ~/.dotfiles ;;
      private|prv)  builtin cd -- ~/.dotfiles-private ;;
      *)            echo "usage: home cd [public|private]" ;;
    esac
  else
    command home "$@"
  fi
}

_home() {
  if (( CURRENT == 3 )) && [[ "${words[2]}" == "cd" ]]; then
    local -a repos=('public:~/.dotfiles' 'private:~/.dotfiles-private')
    _describe 'repo' repos
    return
  fi
  _chezmoi "$@"
}
compdef _home home

# create convenient aliases for commonly used functions
alias git_commit_past='_mrgsh_gcp'           # commit with past date
alias ssh_host_select='_mrgsh_ssh'           # select ssh host from config
alias ssh_host_remove='_mrgsh_rkh'           # remove host from known_hosts
alias rgs='_mrgsh_sg'                        # search file contents (ripgrep)
alias fds='_mrgsh_sf'                        # search filenames (fd)
alias rkh='_mrgsh_rkh'                       # remove host from known_hosts
alias cleanup='_mrgsh_cleanup'               # cleanup macOS junk files
alias set_default_app='_mrgsh_set_default_app' # set default app for dev files

# completion descriptions
compdef '_describe "commit in the past" "(git_commit_past:\"commit with past date\")"' git_commit_past
compdef '_describe "select ssh host" "(ssh_host_select:\"select ssh host from config\")"' ssh_host_select
compdef '_describe "remove host" "(ssh_host_remove:\"remove host from known_hosts\")"' ssh_host_remove
compdef '_describe "search contents" "(rgs:\"search file contents\")"' rgs
compdef '_describe "search files" "(fds:\"search filenames\")"' fds
compdef '_describe "remove host" "(rkh:\"remove host from known_hosts\")"' rkh
compdef '_describe "cleanup junk" "(cleanup:\"cleanup macOS junk files\")"' cleanup
compdef '_describe "set default app" "(set_default_app:\"set default app for dev files\")"' set_default_app

# load keybindings
source ~/.bin/keybindings.sh
