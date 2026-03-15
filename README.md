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

Brewfile for Homebrew on macOS is included at `.config/brewfile/Brewfile`.

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
│  5. just check           │
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

6. Install packages:

   ```bash
   brew bundle --file=~/.config/brewfile/Brewfile
   ```

7. Verify:

   ```bash
   just check
   ```

## Daily workflow

Two commands cover everything. `chezmoi` for public, add `--source
~/.dotfiles-private` for private. A `justfile` handles multi-repo operations
(`just pull`, `just push`).

### Editing a managed file

```bash
# Edit in place, then sync back to source
vim ~/.zshrc
chezmoi re-add ~/.zshrc

# Or edit via chezmoi (opens in $EDITOR, applies on save)
chezmoi edit ~/.zshrc
```

### Adding a new file

```bash
chezmoi add ~/.config/foo/config.toml                            # public
chezmoi --source ~/.dotfiles-private add ~/.config/foo/secret.yml # private
```

### Syncing across machines

```bash
chezmoi update                                    # pull + apply public

git -C ~/.dotfiles-private pull --rebase           # pull private
chezmoi --source ~/.dotfiles-private apply          # apply private

# Or both at once:
just pull
```

### Checking status

```bash
chezmoi diff                                      # public drift
chezmoi --source ~/.dotfiles-private diff           # private drift
chezmoi doctor                                     # health check
```

### Pushing changes

```bash
cd ~/.dotfiles && git add -A && git commit -m "chore: update configs"
git push

# Or both repos at once:
just push
```

### Quick reference

| Task             | chezmoi                                           |
| ---------------- | ------------------------------------------------- |
| Add a file       | `chezmoi add <file>`                              |
| Add (private)    | `chezmoi --source ~/.dotfiles-private add <file>` |
| Apply            | `chezmoi apply`                                   |
| Apply (private)  | `chezmoi --source ~/.dotfiles-private apply`      |
| Pull from remote | `chezmoi update`                                  |
| Check for drift  | `chezmoi diff`                                    |
| Edit a file      | `chezmoi edit <file>`                             |
| Re-sync a file   | `chezmoi re-add <file>`                           |
| List managed     | `chezmoi managed`                                 |

## License

ISC © 2017 Mrugesh Mohapatra
