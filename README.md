# Dotfiles

macOS configuration for Ghostty, zsh, tmux, Neovim, desktop tools, and the Claude Code rig, managed with chezmoi. Private directories, such as `dot_claude/`, are git submodules of a private repository, one branch per directory. Packages live in the [Brewfile repository](https://github.com/raisedadead/Brewfile).

## Install

1. Install Homebrew and 1Password. Enable the 1Password SSH agent.

1. Restore the age identity from 1Password to `~/.config/chezmoi/age-identity.txt`, mode `600`. The private repository README names the item.

1. Run:

   ```sh
   brew install chezmoi git
   chezmoi init --source ~/.dotfiles git@github.com:raisedadead/dotfiles.git
   git -C ~/.dotfiles config core.hooksPath .githooks
   git -C ~/.dotfiles/dot_claude config core.hooksPath .githooks
   ~/.dotfiles/install.sh
   ~/.bin/chezmoi-claude-bootstrap.sh
   ```

## Use

Edit the file in your home directory, then `chezmoi re-add <file>` and commit. [docs/README.md](docs/README.md) holds every command for this setup. [docs/ARCHI.md](docs/ARCHI.md) holds the maintenance context, [docs/MAINTENANCE.md](docs/MAINTENANCE.md) the checks.

## License

ISC © 2017 Mrugesh Mohapatra
