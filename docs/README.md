# Install and daily use

The **source** is the configuration in `~/.dotfiles`. A **target** is the installed file under `$HOME`. To **capture** a change is to copy it from the target back into the source. chezmoi captures a change only when you run a capture command.

The private sources `dot_claude/`, `dot_codex/`, and `dot_pi/` deploy to `~/.claude`, `~/.codex`, and `~/.pi`. The Codex and Pi sources manage only named rig files. Their authentication, hook trust, MCP tokens, sessions, and other runtime state stay local to each machine.

## Install or recover a machine

1. Install Homebrew and 1Password. Enable the 1Password SSH agent.

1. Restore the age identity from 1Password to `~/.config/chezmoi/age-identity.txt` and set its mode to `600`. The private repository README names the item.

1. Initialize and install the dotfiles:

   ```sh
   brew install chezmoi git
   chezmoi init --source ~/.dotfiles git@github.com:raisedadead/dotfiles.git
   ~/.dotfiles/install.sh
   ```

- Keep `--source ~/.dotfiles` on `chezmoi init`. The default source path is different.
- The age identity is not in Git. Without the 1Password copy, you cannot recover the encrypted files.
- The submodules clone over SSH. Make sure that the 1Password SSH agent works first: `ssh -T git@github.com`.
- A clone without submodules needs `git -C ~/.dotfiles submodule update --init`. The doctor fails until you run it.
- `install.sh` takes no arguments.

### Claude Code

Run `~/.bin/chezmoi-claude-bootstrap.sh` to install the runtime prerequisites. See the [Claude checks](MAINTENANCE.md#claude-code).

### Codex

The rig needs Homebrew Python 3.11 or later at `/opt/homebrew/bin/python3`.

1. Run the [Codex checks](MAINTENANCE.md#codex).
1. In a new Codex CLI session, open `/hooks`. Review the new or changed hook definitions.
1. Restart the client after activation.

### Pi

Do not install Pi or a Pi package with `npm install -g`. Install npm-global tools only on the fnm default Node.

1. Install Pi with its installer: `curl -fsSL https://pi.dev/install.sh | sh`. It installs the latest release under `~/.pi/agent/install/` with pinned dependencies.
1. In `pi`, run `/login` for `openai`, `openrouter`, and `typesafe`.
1. Run `pi mcp login cloudflare` and `pi mcp login sentry`.
1. Replay the Pi skills with the loop in [RIG.md](../dot_pi/RIG.md#change-the-rig).
1. Run `npm ci` in `~/.dotfiles/dot_pi`.
1. Run the [Pi checks](MAINTENANCE.md#pi).

The `pi` command is the link `~/.bin/pi` to `~/.pi/agent/bin/pi`. chezmoi manages that link, because `~/.bin` is an exact directory. `pi update` updates Pi. After an update, set the Pi versions in `dot_pi/package.json` to the `pi --version` value. Run `npm install` in `~/.dotfiles/dot_pi`. Then run the [Pi checks](MAINTENANCE.md#pi).

## Daily loop

```sh
nvim ~/.config/zsh/.zshrc              # 1. edit the target
chezmoi status                          # 2. see what differs from source
chezmoi diff ~/.config/zsh/.zshrc       # 3. optional: read the change
chezmoi re-add ~/.config/zsh/.zshrc     # 4. capture it into source
git -C ~/.dotfiles add dot_config/exact_zsh/dot_zshrc
git -C ~/.dotfiles commit -m "feat(zsh): ..."
```

`chezmoi status` prints two columns. Column one is the change since the last apply. Column two is the change that `chezmoi apply` makes. `MM` after a target edit is normal until you `re-add` or apply that target. No output means no drift.

Read `chezmoi status` before a bare `chezmoi re-add`. A bare `re-add` captures every modified target. This includes a change from an installer or a runtime.

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

Capture named files. Do not add or re-add the whole `~/.codex` directory. Its Git and deployment rules allow only the selected rig files.

## A managed Pi file

```sh
chezmoi re-add ~/.pi/agent/extensions/router.ts
cd ~/.dotfiles/dot_pi && npm test
git -C ~/.dotfiles/dot_pi add agent/extensions/router.ts
git -C ~/.dotfiles/dot_pi commit -m "fix(rig): ..."
```

Edit the `settings.json` keys in `dot_pi/agent/modify_settings.json`. Edit the MCP servers in `dot_pi/agent/mcp.json.tmpl`. Then run `chezmoi apply ~/.pi`. `re-add` skips both files. Run `/reload` in an open Pi session.

## Restore a target from source

```sh
chezmoi diff <target>      # read it
chezmoi apply <target>     # overwrite the target from source
```

## Track a new file

| Case             | Command                                                                                | Source entry                                 |
| ---------------- | -------------------------------------------------------------------------------------- | -------------------------------------------- |
| Plain file       | `chezmoi add <target>`                                                                 | `dot_...`                                    |
| Secret file      | `chezmoi add --encrypt <target>`                                                       | `encrypted_...age`; mode 600 adds `private_` |
| Private rig file | Add a named target. Run `chezmoi source-path <target>`. Commit in the owning submodule | inside the submodule                         |

`add --encrypt` skips the secrets scan. `re-add` re-encrypts an encrypted file. A plain `add` of a file that looks like a secret exits 1.

## Files that need a source edit

`re-add` does nothing for a template, a `modify_` script, an external, or a symlink entry. Edit the source, then apply it:

```sh
chezmoi edit --apply <target>     # opens the source file, applies on exit
chezmoi merge <target>            # three-way merge for a template
```

## Exact directories

`~/.bin`, `~/.config/git`, and `~/.config/zsh` are exact. In these directories, `chezmoi apply` removes each file that the source does not hold. Do not keep generated state there.

## Git and private submodules

```sh
git -C ~/.dotfiles status    # lists pending submodule commits
home push                    # pushes submodules, then the parent
```

The operator runs `home push`. A failed submodule push stops the command.

`pre-commit` in both repos runs gitleaks on the staged diff. The parent `pre-push` exits 1 while a recorded submodule commit is on no remote. [ARCHI.md](ARCHI.md#private-submodules) holds the hook details.

Move an existing, tracked directory to the private repo: `~/.bin/dotfiles-privatize.sh <dir> --push`.

## Checks

[MAINTENANCE.md](MAINTENANCE.md) holds the probes. Start with `chezmoi status` and the checks for the component that you changed. For a repository secret scan, run `gitleaks git . --redact --exit-code 1`.
