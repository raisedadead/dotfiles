# Dotfiles

Managed by chezmoi. Two-repo setup: public (`~/.dotfiles`) + private (`~/.dotfiles-private`). Task runner: just (`justfile`). Bootstrap: `install.sh`.

## Chezmoi Conventions

- **Naming**: `dot_` → dotfiles, `executable_` → +x, `private_` → restricted perms, `empty_` → empty files
- **Apply**: `chezmoi apply` (public), `chezmoi --source ~/.dotfiles-private apply` (private)
- **`home()` alias** wraps chezmoi + just: `home check|pull|push|status|verify|managed|init` → just; everything else → chezmoi
- `.claude/*` lives in the **private** repo
- Git hooks: `.githooks/` dir, configured via `core.hooksPath`

## Rules (non-obvious, not derivable from code)

- **keybinds.conf ↔ keyb.yml must stay in sync** — always update both when changing tmux bindings
- **`_tmux_exit_code` must be first precmd** — captures `$?` before OMP modifies it
- **tmux mouse selection is pane-aware** — drag selects within pane, copies to system clipboard via OSC 52; Shift+drag falls back to native Ghostty selection
- **tmux names Shift-Tab as `BTab`** (e.g., `M-BTab`), not `M-S-Tab`
- **`Ctrl+R` is atuin, not fzf** — atuin initialized with `--disable-up-arrow`
- **Emacs mode default** (`bindkey -e`) with `C-z` toggle to vi — required for Alt keybinds without lag
- **Popup scripts live in `dot_config/tmux/scripts/`**, not `dot_bin/`
- **OMP v29+ manages its own cache** — no custom `cached_evalz` for prompt init
- **`cached_evalz` invalidates on binary mtime only** — if a tool needs config-based invalidation, use custom cache logic
- **Shell integration**: cursor + sudo only (not command_status — exit codes handled by zsh precmd)

## Popup Conventions

- Sizes: 70%x80% (lazygit), 53%x60% (fzf-tmux pickers), 40%x45% (command palette), 20%x5 (new session)
- Border: rounded, white
- fzf color scheme: `header:8,pointer:yellow,prompt:yellow,border:white,label:yellow`
- Tab/Shift-Tab cycles categories in sesh-popup and keyb-popup
- Scripts use `fzf-tmux -p` (not `display-popup` + `fzf`) except lazygit

## Status Bar

- Three-zone layout via `status-format[0]` — theme.conf header comments are the canonical reference
- Left: window dots, Centre: session // windows, Right: session squares
- Update theme.conf header comments when changing indicator logic

## Cross-Tool Integration

- **tmux ↔ neovim**: `C-M-h/j/k/l` forwarded via `@pane-is-vim` (requires smart-splits.nvim)
- **tmux ↔ zsh**: `_tmux_exit_code` precmd → `@last_exit_code` window option → status bar error dot
- **tmux ↔ ghostty**: terminal features (hyperlinks, clipboard, extkeys) + `macos-option-as-alt` for Alt binds
- **zsh ↔ yazi**: `C-f` widget opens yazi; `y()` wrapper handles cd-on-exit via temp cwd file

## Validation

- Ghostty: `ghostty +show-config`
- tmux: `tmux source-file ~/.config/tmux/tmux.conf`
- Dotfiles health: `just check`
- Dotfiles sync: `just verify`
- Shell scripts: `shellcheck` (advisory — doesn't support zsh, SC1071 expected)
