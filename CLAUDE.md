# Dotfiles

Managed by [homesick](https://github.com/technicalpickles/homesick). Files in `home/` are symlinked to `~` via `homesick link dotfiles`.

## Structure

```
home/
├── .bin/              # Shell scripts (sourced by .zshrc via functions.sh)
├── .config/
│   ├── tmux/
│   │   ├── tmux.conf  # Main tmux config
│   │   ├── scripts/   # Popup helper scripts (sesh-popup.sh, keyb-popup.sh)
│   │   └── plugins/   # TPM plugins (gitignored)
│   ├── ghostty/config # Terminal config (Catppuccin Mocha theme)
│   ├── keyb/          # Keybinding cheatsheet (keyb.yml + config.yml)
│   ├── sesh/          # Session manager config
│   ├── yazi/          # File manager config
│   └── oh-my-posh/    # Prompt theme
├── .zshrc             # Main shell config
├── .zshenv            # Environment variables
├── .zprofile          # Login shell setup
├── .alias.zshrc       # Aliases
├── .gitconfig         # Git config
└── .fzf.zshrc         # fzf integration
```

## Homesick Linking

- `homesick link dotfiles` symlinks **individual files**, not directories
- New files in `.bin/` or `.config/` need manual symlinks: `ln -s ../.homesick/repos/dotfiles/home/.bin/foo.sh ~/.bin/foo.sh`
- New directories under `.config/` (e.g., `keyb/`) also need manual symlinks for their contents
- Separate repo `dotfiles-nvim` handles neovim config
- Separate repo `dotfiles-private` handles private/machine-specific files

## Keybinding System

- tmux: `M-` (Alt) prefix-free bindings for navigation, `C-M-` for resize
- zsh: emacs mode default (`bindkey -e`) with `C-z` toggle to vi mode — required for Alt keybinds to work without lag
- Vi mode indicator: prompt chevron flips `❯` → `❮` and turns mauve; requires `_omp_get_prompt` re-eval in `zle-keymap-select`
- All keybindings documented in `home/.config/keyb/keyb.yml`, viewable via `M-?` in tmux
- Popup scripts live in `home/.config/tmux/scripts/`, not `.bin/`

## Popup Conventions

All tmux popups follow consistent styling:

- Size: 70%x80% (lazygit), 53%x60% (fzf-tmux pickers)
- Border: rounded, white color
- fzf color scheme: `header:8,pointer:magenta,prompt:magenta,border:white`
- Active category indicator: bright magenta text, inactive: dim (brightblack)
- Scripts use `fzf-tmux -p` for popups (not `display-popup` + `fzf`) except lazygit

## Status Bar

- Window dots: magenta (current), brightyellow (bell), red (error), yellow (activity), brightblack (idle)
- Session squares: green (active + name), brightblack (inactive)
- Exit code tracking via `_tmux_exit_code` precmd hook in `.zshrc`

## zshrc Load Order

- `zsh-defer` is NOT available until after zinit loads it — don't use in the prompt section
- OMP init is cached via `~/.cache/zsh-eval-cache/oh-my-posh.zsh` with binary+config mtime invalidation
- `_omp_kill_bootstrap` prevents re-sourcing 344-line OMP init on every prompt
- OMP spawns 3 subprocesses per startup: init (~30ms), secondary prompt (~18ms), primary prompt (~43ms)
- `cached_evalz` invalidates on binary mtime only; OMP needs config mtime check too (custom cache logic)

## Validation

- Shell scripts: `shellcheck` (advisory — doesn't support zsh, SC1071 expected)
- Ghostty config: `ghostty +show-config` to verify parsing
- tmux config: `tmux source-file` to verify loading
- YAML: `python3 -c "import yaml; yaml.safe_load(open('file'))"`
