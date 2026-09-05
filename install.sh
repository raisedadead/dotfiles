#!/bin/bash
# Bootstrap script for a fresh machine.
# Run: curl -fsLS https://raw.githubusercontent.com/raisedadead/dotfiles/main/install.sh | bash
# Or:  ~/.dotfiles/install.sh

set -euo pipefail

DOTFILES_REPO="git@github.com:raisedadead/dotfiles.git"
BREWFILE_REPO="git@github.com:raisedadead/Brewfile.git"
DOTFILES_DIR="$HOME/.dotfiles"
BREWFILE_DIR="$HOME/.config/brewfile"

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

info() { printf "\033[0;34m[info]\033[0m  %s\n" "$1"; }
ok() { printf "\033[0;32m[ok]\033[0m    %s\n" "$1"; }
warn() { printf "\033[0;33m[warn]\033[0m  %s\n" "$1"; }
err() { printf "\033[0;31m[error]\033[0m %s\n" "$1"; }
ask() { printf "\033[0;35m[action]\033[0m %s\n" "$1"; }

_github_ssh_ok() {
	local out
	out=$(ssh -T git@github.com 2>&1 || true)
	printf '%s' "$out" | grep -q "successfully authenticated"
}

check_cmd() {
	command -v "$1" >/dev/null 2>&1
}

# ─────────────────────────────────────────────────────────────────────────────
# 1. Homebrew
# ─────────────────────────────────────────────────────────────────────────────

info "Checking for Homebrew..."
if check_cmd brew; then
	ok "Homebrew is installed."
else
	warn "Homebrew is not installed."
	ask "Install it with:"
	echo ""
	echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
	echo ""
	ask "Run the command above, then re-run this script."
	exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# 2. Core tools
# ─────────────────────────────────────────────────────────────────────────────

info "Installing core tools..."
for tool in chezmoi git; do
	if check_cmd "$tool"; then
		ok "$tool is installed."
	else
		info "Installing $tool..."
		brew install "$tool"
	fi
done

# ─────────────────────────────────────────────────────────────────────────────
# 3. 1Password SSH agent
# ─────────────────────────────────────────────────────────────────────────────

info "Checking for 1Password SSH agent..."
OP_AGENT="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
if [ -S "$OP_AGENT" ]; then
	ok "1Password SSH agent is running."
else
	warn "1Password SSH agent not found."
	ask "To set it up:"
	echo ""
	echo "  1. Install 1Password from https://1password.com/downloads/mac/"
	echo "     or: brew install --cask 1password"
	echo "  2. Open 1Password → Settings → Developer"
	echo "  3. Enable 'Use the SSH agent'"
	echo "  4. Re-run this script."
	echo ""
	ask "Continue without SSH? (only works if ~/.dotfiles is already cloned) [y/N]"
	reply=""
	if [ -t 0 ]; then read -r reply || true; fi
	if [ "$reply" != "y" ] && [ "$reply" != "Y" ]; then
		exit 1
	fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# 4. Age identity
# ─────────────────────────────────────────────────────────────────────────────

AGE_IDENTITY="$HOME/.config/chezmoi/age-identity.txt"

if [ -f "$AGE_IDENTITY" ]; then
	ok "Age identity present."
else
	warn "Age identity missing at $AGE_IDENTITY"
	ask "Fetch it before continuing, or encrypted files will fail to decrypt:"
	echo ""
	echo "  1. Open 1Password, personal account, vault 'Keys - GPG, PGP, SSH'"
	echo "  2. Find the item 'chezmoi age identity (dotfiles)'"
	echo "  3. mkdir -p $(dirname "$AGE_IDENTITY")"
	echo "  4. Download its document to $AGE_IDENTITY"
	echo "  5. chmod 600 $AGE_IDENTITY"
	echo ""
	if [ -t 0 ]; then read -r -p "Press Enter once it is in place, or Ctrl-C to stop: " _ || true; fi
	if [ ! -f "$AGE_IDENTITY" ]; then
		warn "Still missing — chezmoi apply will fail on encrypted files."
	fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# 5. Dotfiles
# ─────────────────────────────────────────────────────────────────────────────

info "Setting up dotfiles..."
if [ -d "$DOTFILES_DIR/.git" ]; then
	ok "Dotfiles already exist at $DOTFILES_DIR"
	info "Writing the chezmoi config..."
	chezmoi init --source "$DOTFILES_DIR"
else
	chezmoi init "$DOTFILES_REPO" --source "$DOTFILES_DIR"
fi

# Wire the commit guard BEFORE the apply. An apply runs run_ scripts, and a
# failing one aborts this script under `set -e` with the guard still unwired.
if [ -d "$DOTFILES_DIR/.githooks" ]; then
	git -C "$DOTFILES_DIR" config core.hooksPath .githooks
	ok "Git hooks configured."
fi

if [ -f "$DOTFILES_DIR/.gitmodules" ]; then
	git -C "$DOTFILES_DIR" submodule update --init
	git -C "$DOTFILES_DIR" submodule foreach --quiet 'test -d .githooks && git config core.hooksPath .githooks || true'
	ok "Private submodules initialised."
fi

info "Applying..."
chezmoi apply --source "$DOTFILES_DIR"
ok "Dotfiles applied."

# ─────────────────────────────────────────────────────────────────────────────
# 6. Packages
# ─────────────────────────────────────────────────────────────────────────────

info "Setting up Brewfile repo..."
if [ -d "$BREWFILE_DIR" ]; then
	ok "Brewfile repo already exists at $BREWFILE_DIR"
elif _github_ssh_ok; then
	info "Cloning Brewfile repo..."
	git clone "$BREWFILE_REPO" "$BREWFILE_DIR"
	ok "Brewfile repo cloned."
else
	warn "SSH not configured — skipping Brewfile repo clone."
	ask "Set up 1Password SSH agent, then run:"
	echo ""
	echo "  git clone $BREWFILE_REPO $BREWFILE_DIR"
	echo ""
fi

BREWFILE="$BREWFILE_DIR/Brewfile"
if [ -f "$BREWFILE" ]; then
	ask "Install packages from Brewfile? [y/N]"
	reply=""
	if [ -t 0 ]; then read -r reply || true; fi
	if [ "$reply" = "y" ] || [ "$reply" = "Y" ]; then
		info "Installing packages..."
		brew bundle --file="$BREWFILE"
		ok "Packages installed."
	fi
else
	warn "Brewfile not found at $BREWFILE — skipping."
fi

# ─────────────────────────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────────────────────────

echo ""
ok "Setup complete."
info "Run 'chezmoi status' to confirm everything is in sync."
