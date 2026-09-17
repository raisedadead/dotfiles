# Install and daily use

The **source** is the configuration stored in `~/.dotfiles`. A **target** is the installed file under `$HOME`. To capture a change means to copy it from the target back into chezmoi source. This happens only when you run a capture command.

Private sources `dot_claude/` and `dot_codex/` deploy to `~/.claude` and `~/.codex`. The Codex source manages named rig files only; its authentication and runtime state stay local.

## Install or recover a machine

1. Install Homebrew and 1Password. Enable the 1Password SSH agent.

1. Restore the age identity from 1Password to `~/.config/chezmoi/age-identity.txt` and set its mode to `600`. The private repository README names the item.

1. Initialize and install the dotfiles:

   ```sh
   brew install chezmoi git
   chezmoi init --source ~/.dotfiles git@github.com:raisedadead/dotfiles.git
   ~/.dotfiles/install.sh
   ```

The installer configures Git hooks, initializes private submodules, applies the configuration, and offers to install packages from the [Brewfile repository](https://github.com/raisedadead/Brewfile).

- Keep `--source ~/.dotfiles` on `chezmoi init`; the default source path is different.
- The age identity is not in Git. Without the 1Password copy, encrypted files cannot be recovered.
- The submodules clone over SSH, so the 1Password SSH agent must work first: `ssh -T git@github.com`.
- A clone without submodules needs `git -C ~/.dotfiles submodule update --init`; the doctor fails until then.
- `install.sh` takes no arguments. `chezmoi-claude-bootstrap.sh` accepts `--check`, `--only`, and `--skip`.

### Claude Code

Run `~/.bin/chezmoi-claude-bootstrap.sh` to install its runtime prerequisites. See the [Claude checks](MAINTENANCE.md#claude-code).

### Codex

The rig needs Homebrew Python 3.11 or later at `/opt/homebrew/bin/python3`. Run the [Codex checks](MAINTENANCE.md#codex). In a fresh Codex CLI session, open `/hooks` and review new or changed hook definitions. Restart the client after activation. Authentication and hook trust stay local to each machine.

## Daily loop

```sh
nvim ~/.config/zsh/.zshrc              # 1. edit the target
chezmoi status                          # 2. see what differs from source
chezmoi diff ~/.config/zsh/.zshrc       # 3. optional: read the change
chezmoi re-add ~/.config/zsh/.zshrc     # 4. capture it into source
git -C ~/.dotfiles add dot_config/exact_zsh/dot_zshrc
git -C ~/.dotfiles commit -m "feat(zsh): ..."
```

`chezmoi status` prints two columns. Column one is the change since the last apply. Column two is what `chezmoi apply` would do. `MM` after a target edit is normal. No output means no drift.

Read `chezmoi status` before a bare `chezmoi re-add`. A bare `re-add` captures every modified target, including a change an installer or a runtime made.

## A file under `~/.claude`

```sh
chezmoi re-add ~/.claude/settings.json
git -C ~/.dotfiles/dot_claude add settings.json
git -C ~/.dotfiles/dot_claude commit -m "feat(claude): ..."
```

The submodule `post-commit` hook commits the gitlink bump in `~/.dotfiles`. Claude Code rewrites `settings.json` at runtime, so `chezmoi status` lists it again after a session change. Capture it, or restore the source with `chezmoi apply ~/.claude/settings.json`.

## A managed Codex file

```sh
chezmoi re-add ~/.codex/CODE_STYLE.md
git -C ~/.dotfiles/dot_codex add CODE_STYLE.md
git -C ~/.dotfiles/dot_codex commit -m "docs(codex): update code style"
```

Capture named files. Do not add or re-add the whole `~/.codex` directory. Its Git and deployment rules allow only the selected rig files. The private owner plan and audit archive stay in source under `dot_codex/docs/`.

## Restore a target from source

```sh
chezmoi diff <target>      # read it
chezmoi apply <target>     # overwrite the target from source
```

## Track a new file

| Case             | Command                                                                          | Source entry                                 |
| ---------------- | -------------------------------------------------------------------------------- | -------------------------------------------- |
| Plain file       | `chezmoi add <target>`                                                           | `dot_...`                                    |
| Secret file      | `chezmoi add --encrypt <target>`                                                 | `encrypted_...age`; mode 600 adds `private_` |
| Private rig file | Add a named target, inspect its source path, then commit in the owning submodule | inside the submodule                         |

`add --encrypt` skips the secrets scan. `re-add` re-encrypts an encrypted file. A plain `add` of a file that looks like a secret exits 1 (`add.secrets = "error"`).

## Files that need a source edit

`re-add` does nothing for a template, a `modify_` script, an external, or a symlink entry. Edit the source, then apply:

```sh
chezmoi edit --apply <target>     # opens the source file, applies on exit
chezmoi merge <target>            # three-way merge for a template
```

Templates today: `dot_config/glow/glow.yml.tmpl`, `dot_aws/encrypted_private_config.tmpl.age`. Externals: [.chezmoiexternal.toml](../.chezmoiexternal.toml). Modify script: `modify_private_dot_claude.json`.

## Exact directories

`~/.bin`, `~/.config/git`, and `~/.config/zsh` are exact. `chezmoi apply` removes a file there that the source does not hold. Keep generated state elsewhere.

## Inspect

```sh
chezmoi status                  # drift summary
chezmoi diff                    # full diff, target versus source
chezmoi verify; echo $?         # 0 when nothing differs
chezmoi managed                 # every managed path
chezmoi source-path <target>    # the source file for a target
chezmoi cat <target>            # render a target without applying
chezmoi doctor                  # environment check
```

Tab completes chezmoi target paths. Ctrl+T continues the path argument; `<C-g>` in that picker includes Git-ignored paths.

## Git and private submodules

```sh
git -C ~/.dotfiles status                              # lists pending submodule commits
home push                                             # pushes submodules, then the parent
```

Hooks: `pre-commit` in both repos runs gitleaks on the staged diff. The submodule `post-commit` bumps the parent gitlink. The parent `pre-push` exits 1 while a recorded submodule commit is on no remote. Details: [ARCHI.md](ARCHI.md#private-submodules).

The operator runs `home push`. It pushes each initialized submodule recursively, then the parent. A failed submodule push stops the command. `home push` takes no extra arguments. Other `home` commands pass through to chezmoi.

Move an existing, tracked directory to the private repo: `~/.bin/dotfiles-privatize.sh <dir> --push`.

## Checks

[MAINTENANCE.md](MAINTENANCE.md) holds the probes. Start with `chezmoi status` and the checks for the component you changed. Use `gitleaks git . --redact --exit-code 1` for a repository secret scan.
