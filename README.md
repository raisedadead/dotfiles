# Dotfiles

A macOS chezmoi repository for Ghostty, zsh, tmux, Neovim, desktop tools, and the Claude Code rig. Source: `~/.dotfiles`. Packages live in the separate [Brewfile repository](https://github.com/raisedadead/Brewfile). Private directories, such as `dot_claude/`, are git submodules of a private repository, one branch per directory.

## Install or recover

1. Install Homebrew and 1Password. Enable the 1Password SSH agent under **Settings → Developer**.
2. Restore the 1Password document `chezmoi age identity (dotfiles)` from the personal account, vault `Keys - GPG, PGP, SSH`, to `~/.config/chezmoi/age-identity.txt`. Set its mode to `600`.
3. Confirm the SSH agent can reach GitHub: `ssh -T git@github.com`. The private submodules clone over SSH during `chezmoi init`.
4. Run:

   ```sh
   brew install chezmoi git
   chezmoi init --source ~/.dotfiles git@github.com:raisedadead/dotfiles.git
   git -C ~/.dotfiles config core.hooksPath .githooks
   git -C ~/.dotfiles/dot_claude config core.hooksPath .githooks
   ~/.dotfiles/install.sh
   ~/.bin/chezmoi-claude-bootstrap.sh
   ```

`install.sh` takes no arguments. It checks prerequisites, applies the configuration, and installs packages. Run the agent bootstrap separately as shown above. The agent bootstrap supports `--check`, `--only`, and `--skip`: `~/.bin/chezmoi-claude-bootstrap.sh --check`.

The age identity is not in Git. Keep its 1Password copy: without either copy, encrypted files cannot be recovered. Keep `--source ~/.dotfiles` on initialization; the default source path is different. An existing clone without the submodules needs `git -C ~/.dotfiles submodule update --init`; `~/.bin/chezmoi-claude-doctor.sh` fails until then.

## Daily use

```sh
nvim ~/.config/zsh/.zshrc
chezmoi re-add ~/.config/zsh/.zshrc
chezmoi status
chezmoi diff
```

Edit a deployed file, validate it, then capture it. Nothing captures a file on its own: `chezmoi status` lists every edited target until you capture it. Saves do not apply source files automatically. Use `chezmoi edit --apply <target>` when you explicitly want to edit and apply the source.

| Task | Command |
| --- | --- |
| Track a new file | `chezmoi add <target>` |
| Track a secret | `chezmoi add --encrypt <target>` |
| Capture a managed file | `chezmoi re-add <target>` |
| Capture a file under `~/.claude` | `chezmoi re-add <target>`, then commit in `~/.dotfiles/dot_claude`. A hook commits the gitlink in `~/.dotfiles` |
| Move a source directory to the private repository | `~/.bin/dotfiles-privatize.sh <dir> --push` |
| Inspect a proposed apply | `chezmoi status` and `chezmoi diff` |
| Deploy source | `chezmoi apply <target>` |
| List managed paths | `chezmoi managed` |

Templates, modify scripts, and externals need source edits. Exact directories also affect the scope of `re-add`. Read [the deploy gotchas](ARCHI.md#deploy-loop) before either operation.

Tab completes chezmoi target paths, including `~/.config/zsh/` and dotfiles. Ctrl+T continues the path argument at the cursor; `<C-g>` inside that picker includes Git-ignored paths.

[ARCHI.md](ARCHI.md) holds the maintenance context. [MAINTENANCE.md](MAINTENANCE.md) holds checks. [CLAUDE.md](CLAUDE.md) holds project editing rules.

## License

ISC © 2017 Mrugesh Mohapatra
