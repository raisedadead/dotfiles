# Dotfiles

Managed by chezmoi. Two-repo setup: public (`~/.dotfiles`) + private (`~/.dotfiles-private`). Bootstrap: `install.sh`.

## Rules (non-obvious, not derivable from code)

- **Always edit chezmoi source** (`~/.dotfiles/` or `~/.dotfiles-private/`), then `home apply` — never edit target (`~/.config/`, `~/.*`) directly
- **keybinds.conf ↔ keyb.yml must stay in sync** — always update both when changing tmux bindings
- **`_tmux_exit_code` must be first precmd** — captures `$?` before OMP modifies it
- **tmux mouse selection is pane-aware** — drag selects within pane, copies to system clipboard via OSC 52; Shift+drag falls back to native Ghostty selection
- **tmux names Shift-Tab as `BTab`** (e.g., `M-BTab`), not `M-S-Tab`
- **Dual keybindings for Alt+Shift combos** — bind both `M-S-D` (CSI u) and `M-D` (legacy) to the same action. Ghostty 1.3.0+ (#9406) breaks `M-S-*` in modifyOtherKeys mode by stripping the Shift modifier from Option-modified keys on macOS. `extkeys` is intentionally omitted from `terminal-features` to keep Ghostty in legacy mode where case is preserved (`M-d` vs `M-D`). See keybinds.conf and tmux.conf comments for details
- **`Ctrl+R` is atuin, not fzf** — atuin initialized with `--disable-up-arrow`
- **Emacs mode default** (`bindkey -e`) with `C-z` toggle to vi — required for Alt keybinds without lag
- **Popup scripts live in `dot_config/tmux/scripts/`**, not `dot_bin/`
- **OMP v29+ manages its own cache** — no custom `cached_evalz` for prompt init
- **`cached_evalz` invalidates on binary mtime only** — if a tool needs config-based invalidation, use custom cache logic
- **Shell integration**: cursor + sudo only (not command_status — exit codes handled by zsh precmd)

## Cross-Tool Integration

- **tmux ↔ neovim**: `C-M-h/j/k/l` forwarded via `@pane-is-vim` (requires smart-splits.nvim)
- **tmux ↔ zsh**: `_tmux_exit_code` precmd → `@last_exit_code` window option → status bar error dot
- **tmux ↔ ghostty**: terminal features (hyperlinks, clipboard — no extkeys) + `macos-option-as-alt` for Alt binds. `terminal-features` reset with `set -su` before appending to prevent duplicates on config reload
- **zsh ↔ yazi**: `C-f` widget opens yazi; `y()` wrapper handles cd-on-exit via temp cwd file

## Validation

- Ghostty: `ghostty +show-config`
- tmux: `tmux source-file ~/.config/tmux/tmux.conf`
- Dotfiles health: `home check`
- Dotfiles sync: `home sync`
- Shell scripts: `shellcheck` (advisory — doesn't support zsh, SC1071 expected)
