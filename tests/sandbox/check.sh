#!/bin/bash
set -uo pipefail

branch=${1:-main}
fails=0

pass() { printf 'ok   %s\n' "$1"; }
fail() {
	printf 'FAIL %s\n' "$1"
	fails=$((fails + 1))
}
expect() {
	if eval "$2"; then pass "$1"; else fail "$1"; fi
}

apt-get update -qq >/dev/null
apt-get install -y -qq git curl ca-certificates zsh tmux >/dev/null 2>&1
git config --global --add safe.directory '*'
git clone -q --branch "$branch" file:///src "$HOME/dotfiles"

start=$(date +%s)
bash "$HOME/dotfiles/install.sh" >/tmp/install.log 2>&1
status=$?
seconds=$(($(date +%s) - start))
tail -5 /tmp/install.log

expect "install.sh exits 0 (took ${seconds}s)" '[[ $status -eq 0 ]]'
expect "~/.dotfiles points at the clone" '[[ -L $HOME/.dotfiles ]]'
expect "git config is applied" '[[ -f $HOME/.gitconfig ]]'
expect "tmux config is applied" '[[ -f $HOME/.config/tmux/tmux.conf ]]'
expect "zsh config is applied" '[[ -f $HOME/.zshenv && -d $HOME/.config/zsh ]]'
expect "nvim config is applied" '[[ -d $HOME/.config/nvim ]]'
expect "tpm is fetched" '[[ -d $HOME/.config/tmux/plugins/tpm ]]'
expect "no macOS Library tree" '[[ ! -e $HOME/Library ]]'
expect "no macOS app configs" '[[ ! -e $HOME/.config/aerospace && ! -e $HOME/.config/sketchybar && ! -e $HOME/.config/rex ]]'
expect "no ssh config" '[[ ! -e $HOME/.ssh/config ]]'
expect "no encrypted targets" '[[ ! -e $HOME/.wakatime.cfg && ! -e $HOME/.config/gh/hosts.yml ]]'
expect "no agent config without the private submodules" '[[ ! -e $HOME/.claude && ! -e $HOME/.claude.json ]]'
expect "git identity is set" '[[ -n $(git config --global user.email) ]]'
expect "commits are not signed" '[[ -z $(git config --global commit.gpgsign) ]]'
expect "a commit works" 'git init -q /tmp/r && git -C /tmp/r commit -q --allow-empty -m probe'
expect "zsh starts" 'zsh -i -c true </dev/null >/tmp/zsh.log 2>&1'
[[ -s /tmp/zsh.log ]] && head -5 /tmp/zsh.log
expect "a second apply is clean" 'chezmoi --source $HOME/.dotfiles diff --no-pager | wc -c | grep -qx 0'

printf '%s failed\n' "$fails"
exit $((fails > 0))
