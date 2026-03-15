#!/bin/bash
# Bootstrap script for a fresh machine.
# Run: curl -fsLS https://raw.githubusercontent.com/raisedadead/dotfiles/main/install.sh | bash
# Or:  ~/.dotfiles/install.sh

set -euo pipefail

DOTFILES_REPO="git@github.com:raisedadead/dotfiles.git"
PRIVATE_REPO="git@github.com:raisedadead/dotfiles-private.git"
DOTFILES_DIR="$HOME/.dotfiles"
PRIVATE_DIR="$HOME/.dotfiles-private"

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

info()  { printf "\033[0;34m[info]\033[0m  %s\n" "$1"; }
ok()    { printf "\033[0;32m[ok]\033[0m    %s\n" "$1"; }
warn()  { printf "\033[0;33m[warn]\033[0m  %s\n" "$1"; }
err()   { printf "\033[0;31m[error]\033[0m %s\n" "$1"; }
ask()   { printf "\033[0;35m[action]\033[0m %s\n" "$1"; }

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
for tool in chezmoi git just; do
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
  ask "Continue without SSH? (public dotfiles only) [y/N]"
  read -r reply
  if [ "$reply" != "y" ] && [ "$reply" != "Y" ]; then
    exit 1
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# 4. Public dotfiles
# ─────────────────────────────────────────────────────────────────────────────

info "Setting up public dotfiles..."
if [ -d "$DOTFILES_DIR" ]; then
  ok "Public dotfiles already exist at $DOTFILES_DIR"
  info "Applying..."
  chezmoi apply --source "$DOTFILES_DIR"
else
  info "Initializing chezmoi..."
  chezmoi init "$DOTFILES_REPO" --source "$DOTFILES_DIR" --apply
fi
ok "Public dotfiles applied."

# Configure git hooks
if [ -d "$DOTFILES_DIR/.githooks" ]; then
  git -C "$DOTFILES_DIR" config core.hooksPath .githooks
  ok "Git hooks configured."
fi

# ─────────────────────────────────────────────────────────────────────────────
# 5. Private dotfiles
# ─────────────────────────────────────────────────────────────────────────────

info "Setting up private dotfiles..."
if [ -d "$PRIVATE_DIR" ]; then
  ok "Private dotfiles already exist at $PRIVATE_DIR"
  info "Applying..."
  chezmoi --source "$PRIVATE_DIR" apply
  ok "Private dotfiles applied."
elif ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
  info "Cloning private dotfiles..."
  git clone "$PRIVATE_REPO" "$PRIVATE_DIR"
  chezmoi --source "$PRIVATE_DIR" apply
  ok "Private dotfiles applied."
else
  warn "SSH not configured — skipping private dotfiles."
  ask "Set up 1Password SSH agent, then run:"
  echo ""
  echo "  git clone $PRIVATE_REPO $PRIVATE_DIR"
  echo "  chezmoi --source $PRIVATE_DIR apply"
  echo ""
fi

# ─────────────────────────────────────────────────────────────────────────────
# 6. Packages
# ─────────────────────────────────────────────────────────────────────────────

BREWFILE="$HOME/.config/brewfile/Brewfile"
if [ -f "$BREWFILE" ]; then
  ask "Install packages from Brewfile? [y/N]"
  read -r reply
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
info "Run 'home verify' to confirm everything is in sync."
