# Dotfiles

Managed by chezmoi. Two-repo setup: public (`~/.dotfiles`) + private (`~/.dotfiles-private`). Bootstrap: `install.sh`.

## Chezmoi Conventions

- **Naming**: `dot_` → dotfiles, `executable_` → +x, `private_` → restricted perms, `empty_` → empty files
- **Boundary rule**: secrets, auth tokens, or personal tooling config → private repo. Everything else → public repo.
- `.claude/*` lives in the **private** repo (`dot_claude/`)
- Git hooks: `.githooks/` dir in public repo, configured via `core.hooksPath`

## Rules (non-obvious, not derivable from code)

- **Always edit chezmoi source** (`~/.dotfiles/` or `~/.dotfiles-private/`), then `home apply` — never edit target (`~/.config/`, `~/.*`) directly
- **keybinds.conf ↔ keyb.yml must stay in sync** — always update both when changing tmux bindings
- **`_tmux_exit_code` must be first precmd** — captures `$?` before OMP modifies it
- **tmux mouse selection is pane-aware** — drag selects within pane, copies to system clipboard via OSC 52; Shift+drag falls back to native Ghostty selection
- **tmux names Shift-Tab as `BTab`** (e.g., `M-BTab`), not `M-S-Tab`
- **`extended-keys on` requires explicit `M-S-` for shifted keys** — `M-S-D` not `M-D`, `M-S-?` not `M-?`, `M-S-~` not `M-~`. The `S-` denotes the Shift modifier for both letters and punctuation
- **`Ctrl+R` is atuin, not fzf** — atuin initialized with `--disable-up-arrow`
- **Emacs mode default** (`bindkey -e`) with `C-z` toggle to vi — required for Alt keybinds without lag
- **Popup scripts live in `dot_config/tmux/scripts/`**, not `dot_bin/`
- **OMP v29+ manages its own cache** — no custom `cached_evalz` for prompt init
- **`cached_evalz` invalidates on binary mtime only** — if a tool needs config-based invalidation, use custom cache logic
- **Shell integration**: cursor + sudo only (not command_status — exit codes handled by zsh precmd)

## Popup Conventions

- Sizes: 70%x80% (lazygit), 75%x80% (switcher), 37%x60% (keyb-popup), 20%x5 (new session)
- Command palette uses native `display-menu` (no popup size — tmux auto-sizes)
- Border: rounded, white
- fzf color scheme: catppuccin mocha via `FZF_MOCHA_COLORS` in `colors.sh`
- Tab/Shift-Tab cycles categories in switcher and keyb-popup
- Scripts use `fzf-tmux -p` for fzf-based pickers; lazygit and new-session use `display-popup`

## Status Bar

- Three-zone slant layout via `status-format[0]` — theme.conf header comments are the canonical reference
- Left (surface1 bg + slant): window dots with names, zoom/prefix indicators
- Centre (transparent, rounded pill): session name only
- Right (slant + surface1 bg): session squares
- Update theme.conf header comments when changing indicator logic

## Cross-Tool Integration

- **tmux ↔ neovim**: `C-M-h/j/k/l` forwarded via `@pane-is-vim` (requires smart-splits.nvim)
- **tmux ↔ zsh**: `_tmux_exit_code` precmd → `@last_exit_code` window option → status bar error dot
- **tmux ↔ ghostty**: terminal features (hyperlinks, clipboard, extkeys) + `macos-option-as-alt` for Alt binds
- **zsh ↔ yazi**: `C-f` widget opens yazi; `y()` wrapper handles cd-on-exit via temp cwd file

## Validation

- Ghostty: `ghostty +show-config`
- tmux: `tmux source-file ~/.config/tmux/tmux.conf`
- Dotfiles health: `home check`
- Dotfiles sync: `home verify`
- Shell scripts: `shellcheck` (advisory — doesn't support zsh, SC1071 expected)
