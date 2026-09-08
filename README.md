# Dotfiles

My macOS configuration, managed with chezmoi. It includes the terminal, shell, editor, desktop tools, and independent Claude Code and Codex rigs.

This public repository holds shared configuration. Private directories are submodules of a private repository, with one branch per directory. Packages are managed in the [Brewfile repository](https://github.com/raisedadead/Brewfile).

## Install

1. Install Homebrew and 1Password. Enable the 1Password SSH agent.

1. Restore the age identity from 1Password to `~/.config/chezmoi/age-identity.txt` and set its mode to `600`. The private repository README names the item.

1. Initialize and install the dotfiles:

   ```sh
   brew install chezmoi git
   chezmoi init --source ~/.dotfiles git@github.com:raisedadead/dotfiles.git
   ~/.dotfiles/install.sh
   ```

The installer configures Git hooks, initializes private submodules, applies the configuration, and offers to install packages from the Brewfile.

### Claude Code

Run `~/.bin/chezmoi-claude-bootstrap.sh` to install its runtime prerequisites. See the [Claude checks](docs/MAINTENANCE.md#claude-code).

### Codex

The rig needs Homebrew Python 3.11 or later at `/opt/homebrew/bin/python3`. Run the [Codex checks](docs/MAINTENANCE.md#codex). In a fresh Codex CLI session, open `/hooks` and review new or changed hook definitions. Restart the client after activation. Authentication and hook trust stay local to each machine.

## Where to go next

| Task                                    | Read                                      |
| --------------------------------------- | ----------------------------------------- |
| Edit, save, or recover configuration    | [Daily use](docs/README.md)               |
| Understand ownership and load order     | [How this setup works](docs/ARCHI.md)     |
| Validate a change or diagnose a problem | [Maintenance checks](docs/MAINTENANCE.md) |
| Work on this repository with an agent   | [Project instructions](AGENTS.md)         |

## License

ISC © 2017 Mrugesh Mohapatra
