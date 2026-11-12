# Install and daily use

The **source** is the configuration in `~/.dotfiles`. A **target** is the installed file under `$HOME`. To **capture** a change is to copy it from the target back into the source. chezmoi captures a change only when you run a capture command.

The private sources `dot_claude/`, `dot_agents/`, and `dot_pi/` deploy to `~/.claude`, `~/.agents`, and `~/.pi`. The Pi source manages only named rig files. Its authentication, hook trust, MCP tokens, sessions, and other runtime state stay local to each machine.

## Install or recover a machine

1. Install Homebrew and 1Password. Enable the 1Password SSH agent.

1. Restore the age identity from 1Password to `~/.config/chezmoi/age-identity.txt` and set its mode to `600`. The private repository README names the item.

1. Initialize and install the dotfiles:

   ```sh
   brew install chezmoi git fnm
   chezmoi init --source ~/.dotfiles git@github.com:raisedadead/dotfiles.git
   ~/.dotfiles/install.sh
   ```

- Keep `--source ~/.dotfiles` on `chezmoi init`. The default source path is different.
- The age identity is not in Git. Without the 1Password copy, you cannot recover the encrypted files.
- The submodules clone over SSH. Test the 1Password SSH agent first: `ssh -T git@github.com`.

### Linux sandbox

To use this repository as dotfiles in a Codespace or another Linux sandbox, select it as the dotfiles repository. Codespaces runs `install.sh`. On Linux, `install.sh` applies only the shell, git, editor and tmux configuration:

- It installs a pinned chezmoi to `~/.local/bin` when chezmoi is not on `PATH`.
- It links `~/.dotfiles` to the clone and runs `chezmoi init --apply`.
- It does not install Homebrew or tools. It does not clone the private submodules.

`.chezmoiignore` skips the macOS-only targets on Linux. It skips the encrypted targets, `~/.ssh`, and commit signing when the age identity or the signing key is not present. It skips the agent configuration when the `dot_claude` submodule is empty. Check the result with the [sandbox check](MAINTENANCE.md#x1-linux-sandbox).

### Pi

Do not install Pi or a Pi package with `npm install -g`. Install npm-global tools only on the fnm default Node.

1. Install Pi with its installer: `curl -fsSL https://pi.dev/install.sh | sh`. It installs the latest release under `~/.pi/agent/install/` with pinned dependencies.
1. In `pi`, run `/login` for `openai`, `openrouter`, and `typesafe`.
1. Run `pi mcp login cloudflare` and `pi mcp login sentry`.
1. Replay the Pi skills with the loop in [RIG.md](../dot_pi/RIG.md#change-the-rig).
1. Run `npm ci` in `~/.dotfiles/dot_pi`.
1. Run the [Pi checks](MAINTENANCE.md#pi).

`~/.bin/pi` links to `~/.pi/agent/bin/pi`. After `pi update`, set the Pi versions in `dot_pi/package.json` to the `pi --version` value, run `npm install` in `~/.dotfiles/dot_pi`, then run the [Pi checks](MAINTENANCE.md#pi).

### Rex

1. Install the Rex beta app, `Rex Beta.app`, in `/Applications`. Rex has no Homebrew cask. The `rex` command is the link `~/.bin/rex` into this app.
1. Run `chezmoi apply`. It writes the Rex app settings and the `xterm-rex` terminfo entry. Restart the server once, with no work running, so that new panes get `TERM=xterm-rex`.
1. Run the [Rex checks](MAINTENANCE.md#rex).

Rex does not read its config again when a file changes. After you apply a Rex config file, load it:

```sh
chezmoi apply ~/.config/rex
rex config check && rex config reload
```

A reload that prints no error loaded the file. If it fails, the server keeps the keys of the last good load. A server that starts with a bad config has no keys, so `chezmoi apply` runs the check first and stops on an error. Correct the source, then apply and load it again.

After a Rex restart, run **Resume After Restart** from the command palette. It resumes Claude Code and Pi in their panes, closes restored popups and hand-off floats, and starts the editor again in editor panes.

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

If column one shows a change, run `chezmoi apply` in a terminal, not in an agent shell such as Pi's `!`. Without a terminal, chezmoi cannot ask whether to overwrite that target. It stops at the first such target, exits 1 with `could not open a new TTY`, and skips every later target.

## A file under `~/.claude`

```sh
chezmoi re-add ~/.claude/CLAUDE.md
git -C ~/.dotfiles/dot_claude add CLAUDE.md
git -C ~/.dotfiles/dot_claude commit -m "feat(claude): ..."
```

The submodule `post-commit` hook commits the gitlink bump in `~/.dotfiles`.

`settings.json` is a modify script. Edit the managed keys in `dot_claude/.settings.managed.json`. To remove a key from the target, add its path to the removed list in `dot_claude/modify_settings.json`. Then run `chezmoi apply ~/.claude/settings.json`. The script keeps the keys that Claude Code writes at run time, so those keys do not show as drift. `re-add` skips the file.

## A managed Pi file

Follow [Change the rig](../dot_pi/RIG.md#change-the-rig). Edit the `settings.json` keys in `dot_pi/agent/modify_settings.json` and the MCP servers in `dot_pi/agent/mcp.json.tmpl`. `re-add` skips both files.

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

`re-add` skips some entry kinds ([ARCHI.md](ARCHI.md#deployment-and-capture)). Edit the source, then apply it:

```sh
chezmoi edit --apply <target>     # opens the source file, applies on exit
chezmoi merge <target>            # three-way merge for a template
```

## Git and private submodules

```sh
git -C ~/.dotfiles status    # lists pending submodule commits
home push                    # pushes submodules, then the parent
```

The operator runs `home push`. A failed submodule push stops it. `home <args>` runs `chezmoi <args>` for any other command.

[ARCHI.md](ARCHI.md#private-submodules) holds the Git hook details.

Move an existing, tracked directory to the private repo: `~/.bin/dotfiles-privatize.sh <dir> --push`.

## Checks

[MAINTENANCE.md](MAINTENANCE.md) holds the probes. Start with `chezmoi status` and the checks for the component that you changed. For a repository secret scan, run `gitleaks git . --redact --exit-code 1`.
