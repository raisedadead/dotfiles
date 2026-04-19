# [@raisedadead](https://github.com/raisedadead)'s dotfiles

> ### Every-day carry for my systems.

Managed with [`chezmoi`](https://www.chezmoi.io/). Previously managed with
[`homeshick`](https://github.com/andsens/homeshick), which served reliably for
years.

## Structure

This repository is the public dotfiles source. A separate private repository
handles credentials and sensitive configuration.

```
~/.dotfiles           # this repo (public)
~/.dotfiles-private   # private repo
```

## Packages and tools

Homebrew package management lives in a separate repo by design. When that repo is
applied, it provides `~/.config/brewfile/Brewfile`.

```bash
brew bundle --file=~/.config/brewfile/Brewfile
```

## Setup (new machine)

A bootstrap script handles the full sequence interactively:

```bash
# If you already have Homebrew + git:
git clone git@github.com:raisedadead/dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh

# Or step by step — see below.
```

```
┌──────────────────────────┐
│  1. Install Homebrew     │
└────────────┬─────────────┘
             ▼
┌──────────────────────────┐
│  2. brew install         │
│     chezmoi git just     │
└────────────┬─────────────┘
             ▼
┌──────────────────────────┐     ┌─────────────────────────┐
│  3. Install 1Password    │────▶│ Enable SSH Agent in     │
│     (manual / brew)      │     │ Settings → Developer    │
└────────────┬─────────────┘     └─────────────────────────┘
             ▼
┌──────────────────────────┐
│  4. ./install.sh         │
│     ├─ apply public      │
│     ├─ clone + apply     │
│     │  private (if SSH)  │
│     └─ brew bundle       │
└────────────┬─────────────┘
             ▼
┌──────────────────────────┐
│  5. home check           │
└──────────────────────────┘
```

### Manual steps (if not using install.sh)

1. Install [Homebrew](https://brew.sh/):

   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. Install essentials:

   ```bash
   brew install chezmoi git just
   ```

3. Set up [1Password](https://1password.com/downloads/mac/) and enable the SSH
   agent under **Settings → Developer → SSH Agent**.

4. Apply public dotfiles:

   ```bash
   chezmoi init git@github.com:raisedadead/dotfiles.git --source ~/.dotfiles --apply
   ```

5. Apply private dotfiles:

   ```bash
   git clone git@github.com:raisedadead/dotfiles-private.git ~/.dotfiles-private
   chezmoi --source ~/.dotfiles-private apply
   ```

6. Install packages (optional, if your separate Brewfile repo is already
   applied):

   ```bash
   brew bundle --file=~/.config/brewfile/Brewfile
   ```

7. Verify:

   ```bash
   home check
   ```

## Daily workflow

`home` is the day-to-day entrypoint. It wraps the public + private chezmoi
repos and gives you status, sync, apply, pull, and push commands that work
across both.

### Editing a managed file

```bash
# Edit chezmoi source directly, then apply
$EDITOR ~/.dotfiles/dot_zshrc
home apply

# Or edit via chezmoi without touching the target file
home pub edit ~/.zshrc
```

### Adding a new file

```bash
home pub add ~/.config/foo/config.toml
home prv add ~/.config/foo/secret.yml
```

### Syncing across machines

```bash
home pull
home apply
```

### Checking status

```bash
home check
```

### Pushing changes

```bash
git -C ~/.dotfiles add -A && git -C ~/.dotfiles commit -m "chore: update configs"

# If private repo changed too:
git -C ~/.dotfiles-private add -A && git -C ~/.dotfiles-private commit -m "chore: update configs"

home push
```

### Quick reference

| Task                      | Command                         |
| ------------------------- | ------------------------------- |
| Add a file (public)       | `home pub add <file>`           |
| Add a file (private)      | `home prv add <file>`           |
| Edit a file (public)      | `home pub edit <file>`          |
| Edit a file (private)     | `home prv edit <file>`          |
| Apply both repos          | `home apply`                    |
| Pull both repos           | `home pull`                     |
| Check status and drift    | `home check`                    |
| Recover target-side edits | `home re-add`                   |
| List managed files        | `home pub managed` / `home prv managed` |

## License

ISC © 2017 Mrugesh Mohapatra
