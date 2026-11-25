# Install and daily use

This document covers the install steps and the daily chezmoi commands.

The **source** is the configuration in `~/.dotfiles`. A **target** is the installed file under `$HOME`. To **capture** a change is to copy it from the target into the source. chezmoi captures a change only when you run a capture command.

The private sources `dot_claude/` and `dot_omp/` deploy to `~/.claude` and `~/.omp`, respectively.

## Install or recover a machine

1. Install Homebrew and 1Password. Enable the 1Password SSH agent.

1. Restore the age identity from 1Password to `~/.config/chezmoi/age-identity.txt`. Set its mode to `600`.

1. Initialize and install the dotfiles:

   ```sh
   brew install chezmoi git fnm
   chezmoi init --source ~/.dotfiles git@github.com:raisedadead/dotfiles.git
   ~/.dotfiles/install.sh
   ```

- Keep `--source ~/.dotfiles` on `chezmoi init`.
- The submodules clone over SSH. Test the SSH agent first: `ssh -T git@github.com`.

### Linux sandbox

To use this repository in a Codespace, select it as the dotfiles repository. On Linux, `install.sh` applies only the shell, git, editor and tmux configuration. It installs no tools and clones no private submodule. Run the [sandbox check](MAINTENANCE.md#x1-linux-sandbox).

### Rex

1. Install `Rex.app` in `/Applications`. The `rex` command is the link `~/.bin/rex` into this app.
1. Run `chezmoi apply`. Restart the Rex server once, with no work running.
1. Run the [Rex checks](MAINTENANCE.md#rex).

Rex does not read its config again when a file changes. After you apply a Rex config file, load it:

```sh
chezmoi apply ~/.config/rex
rex config check && rex config reload
```

If the reload fails, the server keeps the keys of the last good load. Correct the source, then apply and load it again.

## Daily loop

```sh
nvim ~/.config/zsh/.zshrc              # 1. edit the target
chezmoi status                          # 2. see what differs from source
chezmoi diff ~/.config/zsh/.zshrc       # 3. optional: read the change
chezmoi re-add ~/.config/zsh/.zshrc     # 4. capture it into source
git -C ~/.dotfiles add dot_config/exact_zsh/dot_zshrc
git -C ~/.dotfiles commit -m "feat(zsh): ..."
```

No output from `chezmoi status` means no drift.

Run `chezmoi apply` in a terminal, not in an agent shell. Without a terminal, chezmoi exits 1 with `could not open a new TTY`.

## A file under `~/.claude`

The full loop is [ARCHI.md "Deployment and capture"](ARCHI.md#deployment-and-capture). After an edit in place:

```sh
chezmoi re-add ~/.claude/CLAUDE.md
git -C ~/.dotfiles/dot_claude add CLAUDE.md
git -C ~/.dotfiles/dot_claude commit -m "feat(claude): ..."
```

`settings.json` is a modify script, and `re-add` skips it. Edit the managed keys in `dot_claude/.settings.managed.json`. To remove a key, add its path to the removed list in `dot_claude/modify_settings.json`. Then run `chezmoi apply ~/.claude/settings.json`.

## Oh My Pi

The macOS Brewfile installs `omp`. On a fresh machine it uses its normal defaults except for the preferences in `dot_omp/agent/.config.managed.yml`. chezmoi merges those keys into `~/.omp/agent/config.yml` and leaves other settings in place.

To keep a preference changed in `/settings`, copy just that key and value into `.config.managed.yml`. `chezmoi re-add` skips the modify template; don't capture the entire live file. Edit the manifest, commit in `dot_omp/`, and apply the named target:

```sh
home apply ~/.omp/agent/config.yml
```

Removing a key from the manifest stops managing it; reset it in OMP separately if you want the default back. Omit credentials, setup and consent flags, model routing, and other machine-local settings. Sign in separately on each machine.

## Restore a target from source

Run `chezmoi diff <target>`, then `chezmoi apply <target>`. The operator runs `home apply <target>`.

## Track a new file

- Plain file: `chezmoi add <target>`.
- Secret file: `chezmoi add --encrypt <target>`. The source entry is `encrypted_...age`.
- Private rig file: run `chezmoi source-path <target>`, then commit in the owning submodule.

## Files that need a source edit

`re-add` skips templates, modify scripts and externals. Edit the source, then apply it:

```sh
chezmoi edit --apply <target>     # opens the source file, applies on exit
chezmoi merge <target>            # three-way merge for a template
```

## Git and private submodules

```sh
git -C ~/.dotfiles status    # lists pending submodule commits
home push                    # pushes submodules, then the parent
```

The operator runs `home push`. `home <args>` runs `chezmoi <args>`. The hook details are in [ARCHI.md](ARCHI.md#private-submodules).

## Checks

[MAINTENANCE.md](MAINTENANCE.md) holds the probes. Run `chezmoi status`, then the checks for the component that you changed. To scan for secrets, run `gitleaks git . --redact --exit-code 1`.
