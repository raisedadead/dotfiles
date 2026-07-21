# Dotfiles

Managed by chezmoi. Two-repo setup: public (`~/.dotfiles`) + private (`~/.dotfiles-private`). Bootstrap: `install.sh`.

This half holds shell / tmux / ghostty / nvim / OMP and cross-tool integration. The Claude Code rig, every other agent rig, secrets, and personal tooling live in the private half — see [`~/.dotfiles-private/CLAUDE.md`](~/.dotfiles-private/CLAUDE.md). The split is by audit surface, not by importance: this repo's `.chezmoiignore` excludes `.claude` and `CLAUDE.md` so the private half is the sole source of truth for agent config.

## Rules (non-obvious, not derivable from code)

- **Source-first re-add loop** — never edit the runtime target (`~/.config/`, `~/.*`) as the source of truth. The loop is: (1) edit chezmoi source (`~/.dotfiles/` or `~/.dotfiles-private/`); (2) `home apply` to deploy source to the runtime target; (3) validate the live/runtime config with the tool's own validator (see Validation section); (4) `home re-add` to capture the validated runtime back into source. Source stays canonical; re-add closes the loop and captures any normalization the tool applied to its own config
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
- **`set -g detach-on-destroy off`** — required for park/save/unpark UX; keeps client attached to a remaining session when the current one is destroyed
- **Session persistence is intentionally manual** — park/save/unpark scripts replace tmux-resurrect/continuum; no auto-restore on boot
- **Switcher/menu use `#{session_id}` not `#{session_name}`** — tmux session names can contain apostrophes/quotes that break shell-style escaping in `display-menu` command strings; numeric `$N` IDs are quote-safe

## Cross-Tool Integration

- **tmux ↔ neovim**: `M-H/J/K/L` forwarded via `@pane-is-vim` (requires smart-splits.nvim)
- **tmux ↔ zsh**: `_tmux_exit_code` precmd → `@last_exit_code` window option → status bar error dot
- **tmux ↔ ghostty**: terminal features (hyperlinks, clipboard — no extkeys) + `macos-option-as-alt` for Alt binds. `terminal-features` reset with `set -su` before appending to prevent duplicates on config reload
- **zsh ↔ yazi**: `C-f` widget opens yazi; `y()` wrapper handles cd-on-exit via temp cwd file

## Validation

- Ghostty: `ghostty +show-config`
- tmux: `tmux source-file ~/.config/tmux/tmux.conf`
- Dotfiles health: `home check`
- Dotfiles sync: `home sync`
- Shell scripts: `shellcheck` (advisory — doesn't support zsh, SC1071 expected)
