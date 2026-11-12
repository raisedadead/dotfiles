#!/bin/bash
set -uo pipefail

branch=${1:-main}
fails=0

check() {
	local label=$1
	shift
	if "$@"; then
		printf 'ok   %s\n' "$label"
	else
		printf 'FAIL %s\n' "$label"
		fails=$((fails + 1))
	fi
}

absent() { [ ! -e "$1" ] && [ ! -L "$1" ]; }
unset_key() { [ -z "$(git config --global --includes "$1")" ]; }
set_key() { [ -n "$(git config --global --includes "$1")" ]; }
clean_reapply() {
	local diff
	diff=$(chezmoi --source "$HOME/.dotfiles" diff --no-pager)
	[ -z "$diff" ] || printf '%s\n' "$diff" | head -20
	[ -z "$diff" ]
}

apt-get update -qq >/dev/null
apt-get install -y -qq git curl ca-certificates zsh tmux >/dev/null 2>&1
git config --global --add safe.directory '*'
git clone -q --branch "$branch" file:///src "$HOME/dotfiles"

start=$(date +%s)
bash "$HOME/dotfiles/install.sh" >/tmp/install.log 2>&1
code=$?
seconds=$(($(date +%s) - start))
tail -5 /tmp/install.log
export PATH="$HOME/.local/bin:$PATH"

check "install.sh exits 0 in ${seconds}s" [ "$code" -eq 0 ]
check "the .dotfiles link points at the clone" [ -L "$HOME/.dotfiles" ]
check "git config is applied" [ -f "$HOME/.gitconfig" ]
check "tmux config is applied" [ -f "$HOME/.config/tmux/tmux.conf" ]
check "zsh env is applied" [ -f "$HOME/.zshenv" ]
check "zsh config is applied" [ -d "$HOME/.config/zsh" ]
check "nvim config is applied" [ -d "$HOME/.config/nvim" ]
check "tpm is fetched" [ -d "$HOME/.config/tmux/plugins/tpm" ]
check "no Library tree" absent "$HOME/Library"
check "no aerospace config" absent "$HOME/.config/aerospace"
check "no sketchybar config" absent "$HOME/.config/sketchybar"
check "no rex config" absent "$HOME/.config/rex"
check "no ssh config" absent "$HOME/.ssh/config"
check "no wakatime secret" absent "$HOME/.wakatime.cfg"
check "no gh hosts secret" absent "$HOME/.config/gh/hosts.yml"
check "no claude config" absent "$HOME/.claude"
check "no claude.json" absent "$HOME/.claude.json"
check "git identity is set" set_key user.email
check "commits are not signed" unset_key commit.gpgsign
git init -q /tmp/r
check "a commit works" git -C /tmp/r commit -q --allow-empty -m probe
check "zsh starts" zsh -i -c true </dev/null
check "a second apply has nothing to change" clean_reapply

printf '%s failed\n' "$fails"
[ "$fails" -eq 0 ]
