# chezmoi commands for this setup

Source: `~/.dotfiles`. Target: `$HOME`. Private tree: `~/.dotfiles/dot_claude`, a git submodule that deploys to `~/.claude`. Edit the target file, then capture it. Nothing captures a file on its own.

## Daily loop

```sh
nvim ~/.config/zsh/.zshrc              # 1. edit the target
chezmoi status                          # 2. see what differs from source
chezmoi diff ~/.config/zsh/.zshrc       # 3. optional: read the change
chezmoi re-add ~/.config/zsh/.zshrc     # 4. capture it into source
git -C ~/.dotfiles commit -am "feat(zsh): ..."
```

`chezmoi status` prints two columns. Column one is the change since the last apply. Column two is what `chezmoi apply` would do. `MM` after a target edit is normal. An empty line means no drift.

Read `chezmoi status` before a bare `chezmoi re-add`. A bare `re-add` captures every modified target, including a change an installer or a runtime made.

## A file under `~/.claude`

```sh
chezmoi re-add ~/.claude/settings.json
git -C ~/.dotfiles/dot_claude commit -am "feat(claude): ..."
```

The submodule `post-commit` hook then commits the gitlink bump in `~/.dotfiles`. Claude Code rewrites `settings.json` at runtime, so `chezmoi status` can list it again after a session change. Capture it when you want the runtime values, or run `chezmoi apply ~/.claude/settings.json` to restore the source.

## Reject a change you did not make

```sh
chezmoi diff <target>      # read it
chezmoi apply <target>     # overwrite the target from source
```

## Track a new file

| Case                   | Command                                             | Source entry                                 |
| ---------------------- | --------------------------------------------------- | -------------------------------------------- |
| Plain file             | `chezmoi add <target>`                              | `dot_...`                                    |
| Secret file            | `chezmoi add --encrypt <target>`                    | `encrypted_...age`; mode 600 adds `private_` |
| File under `~/.claude` | `chezmoi add <target>`, then commit in `dot_claude` | inside the submodule                         |

`add --encrypt` skips the secrets scan. `re-add` re-encrypts an encrypted file. `add.secrets = "error"` stops a plain `add` of a file that looks like a secret.

## Files that need a source edit

`re-add` does nothing for a template, a `modify_` script, an external, or a symlink entry. Edit the source, then apply:

```sh
chezmoi edit --apply <target>     # opens the source file, applies on exit
chezmoi merge <target>            # three-way merge for a template
```

Templates today: `dot_config/glow/glow.yml.tmpl`, `dot_aws/encrypted_private_config.tmpl.age`. Externals: [.chezmoiexternal.toml](../.chezmoiexternal.toml). Modify script: `modify_private_dot_claude.json`.

## Exact directories

`~/.bin`, `~/.config/git`, and `~/.config/zsh` are exact. `chezmoi apply` removes a file there that the source does not hold. Keep generated state out of those directories.

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

## Git and the submodule

```sh
git -C ~/.dotfiles status                              # lists pending submodule commits
git -C ~/.dotfiles/dot_claude push origin dot_claude   # the submodule first
git -C ~/.dotfiles push                                # then the parent
```

The parent `pre-push` hook exits 1 while a recorded submodule commit is on no remote; see `.githooks/pre-push`. Hooks in both repos: `pre-commit` runs gitleaks on the staged diff. The submodule `post-commit` bumps the parent gitlink. The settings that make this work live in `~/.gitconfig`: `submodule.recurse = false`, `push.recurseSubmodules = on-demand`, `submodule.dot_claude.update = merge`, `status.submoduleSummary = true`.

Move a directory to the private repo: `~/.bin/dotfiles-privatize.sh <dir> --push`.

## Recover a machine

Follow [README.md](../README.md). In short: the 1Password SSH agent, the age identity from 1Password, `chezmoi init --source ~/.dotfiles git@github.com:raisedadead/dotfiles.git`, the hook paths, then `install.sh`.

## Checks

[MAINTENANCE.md](../MAINTENANCE.md) holds the probes. The quick set: `chezmoi status`, `~/.bin/chezmoi-claude-doctor.sh`, and `gitleaks git . --exit-code 1` in `~/.dotfiles`.
