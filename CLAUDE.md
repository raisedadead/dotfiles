# Dotfiles

Chezmoi, two repos: public (`~/.dotfiles`) + private (`~/.dotfiles-private`), split by audit surface. Bootstrap: `install.sh`. This half: shell / tmux / ghostty / nvim / OMP and cross-tool integration. Agent rigs, secrets, personal tooling: private half — [`~/.dotfiles-private/CLAUDE.md`](~/.dotfiles-private/CLAUDE.md). This repo's `.chezmoiignore` excludes `.claude` and `CLAUDE.md`, so the private half is sole source of truth for agent config.

## Rules (non-obvious, not derivable from code)

- **Source-first re-add loop** — edit source → `home apply` → validate runtime with the tool's own validator → `home re-add`. Runtime is never the source of truth. Operational form injected per-edit by `~/.claude/rules/10-chezmoi.md`.
- **`RUNTIME_KEYS` is empty by design** — nothing is harvested live→source; an unmirrored `/model` or `/config` change is wiped on next apply. `PRIV_RUNTIME_OWNED` force-applies `~/.claude/settings.json` + `~/.pi/agent/settings.json`. Mechanism: [`~/.dotfiles-private/ARCHI.md`](~/.dotfiles-private/ARCHI.md) "Deploy loop".
- **chezmoi never prunes** — a deleted source file leaves its deployed target; `rm` it manually after `apply` or it becomes an unflagged orphan.
- **keybinds.conf ↔ keyb.yml stay in sync** — update both on any tmux binding change.
- **The workspace list lives in THREE files** — `dot_config/sketchybar/lua/items/spaces.lua`, `dot_config/sketchybar/executable_sketchybarrc` (`left_island` bracket), `dot_config/aerospace/aerospace.toml` (`persistent-workspaces`). Fewer than all three renders but falls outside the island, no error (drifted once — `1e2658e`). Do not DRY it away; update all three.
- **tmux mouse selection is pane-aware** — drag copies via OSC 52; Shift+drag falls back to native Ghostty selection.
- **tmux names Shift-Tab `BTab`** (`M-BTab`, not `M-S-Tab`).
- **Dual keybindings for Alt+Shift combos** — bind both `M-S-D` (CSI u) and `M-D` (legacy). Ghostty 1.3.0+ (#9406) strips Shift from Option-modified keys in modifyOtherKeys mode; `extkeys` is deliberately omitted from `terminal-features` to stay in legacy mode where case survives. Details in keybinds.conf/tmux.conf comments.
- **zsh's `Ctrl+Shift+W/E/A/S` are Ghostty rewrites arbitrated by tmux, not zsh keys** — in legacy encoding no terminal can tell `Ctrl+Shift+X` from `Ctrl+X` (one control byte either way), so `config.ghostty` maps each to `text:\x1b\x<byte>`; tmux receives `M-C-x` and splits it on `@pane-is-vim` exactly like `M-H/J/K/L` — vim panes get plain `Ctrl+X` back, every other pane gets `M-C-x`, which `.zshrc` binds as `^[^X`. The vim branch exists so vim panes keep native `Ctrl+X` semantics rather than a stray `<Esc>` prefix; it is **mode-scoped, not blanket protection** — probed on a throwaway socket with buffer `5 foo`: in insert mode the branch turns `<Esc><C-a>` (increments to `6 foo`) into `i_CTRL-A` (`5 foo5 foo`), but in normal mode both paths increment identically, because plain `C-a` increments too. Three residual holes, accepted: `Ctrl+Shift+A` still increments in neovim normal mode (only an nvim-side remap could stop that); outside tmux (quick terminal, bare Ghostty) there is no arbitration; and `beginning-of-line`/`end-of-line` exist only under Ghostty, since `^A`/`^E` are reassigned and Home/End are unbound in this rig.
- **Forward zsh motions bind the `.`-prefixed builtin widgets** — `bindkey '^S' .forward-word`, `'^[^S' .end-of-line`. zsh-autosuggestions' `_zsh_autosuggest_bind_widgets` lists `.*` in its `ignore_widgets`, so the dot form moves the cursor without swallowing the suggestion; the undotted names are in its PARTIAL_ACCEPT / ACCEPT lists and are used deliberately on `Ctrl+E` / `Ctrl+Shift+E`. Backward motions need no guard — nothing accepts leftwards, and `_zsh_autosuggest_modify` restores POSTDISPLAY when the buffer is unchanged.
- **`Ctrl+F` is yazi, bound in `dot_bin/keybindings.sh`** — sourced from `.zshrc` via `~/.bin/functions.sh` *after* the keybinding block, so any `bindkey '^f'` earlier in `.zshrc` is silently overridden.
- **`Ctrl+R` is atuin, not fzf** — atuin runs `--disable-up-arrow`.
- **Emacs mode default** (`bindkey -e`), `C-z` toggles vi — required for lag-free Alt binds.
- **Popup scripts live in `dot_config/tmux/scripts/`**, not `dot_bin/`.
- **zsh config lives in `$ZDOTDIR` (`~/.config/zsh/`)** — `~/.zshenv` is a 2-line stub; with `ZDOTDIR` set there, `$ZDOTDIR/.zshenv` is never auto-read, so the stub sources it explicitly. Probe: `ARCHI.md` §3.
- **PATH lives in `path.zsh`, called from BOTH `.zshenv` and `.zprofile`** — macOS `path_helper` (via `/etc/zprofile`) hoists `/etc/paths` and only `.zprofile` runs after it. **Never verify PATH with `zsh -i -c` alone** — non-login, `path_helper` never fires. Test `-l -i`, `-i`, and bare. Full story: `ARCHI.md` §3.
- **`path.zsh` prepends fnm's *default alias* dir** (`~/.local/share/fnm/aliases/default/bin` — static symlink, no `fnm env` spawn) and it must sit **above `$HOMEBREW_PREFIX/bin`**. `_mrgsh_path_prepend` prepends each arg in turn, so the LAST argument lands FIRST in PATH. Without this, non-interactive zsh resolved Homebrew's node (transitive dep, two majors ahead) and fresh non-descendant shells (cron, LaunchAgent, GUI) lost `wrangler`/`cavemem`/`pnpm`. Interactive shells still get per-shell semantics from `.zshrc`'s later `fnm env`. Verify all four: `zsh -c`, `-i -c`, `-l -i -c`, `env -i … zsh -c`. **`dot_bashrc` carries the same prepend and must stay in sync** (it shipped the identical bug). The four root-owned `/usr/local/bin` symlinks into `fnm/aliases/default` are unmanaged machine state, not created by `install.sh`; they matter only for GUI/LaunchAgent processes reading no rc.
- **zsh startup is intentionally synchronous** — no plugin manager, no defer, no eval caching; plain clones in `$XDG_DATA_HOME/zsh/plugins` (update: `zsh-plugin-update`), direct `eval "$(tool init zsh)"`. Measured median 123ms (n=15, 2026-08-01). Do not re-introduce zinit/zsh-defer/eval caches. Budget + profile: `ARCHI.md` §4.
- **Static completions live in `~/.zfunc`** — generated by `update-completions` (run after upgrading gh/op/wrangler); never eval'd at startup.
- **OMP never reaps its per-session cache files** — `.zshrc` keeps the newest 50, glob `*.*-*-*-*-*.omp.cache` (UUID infix load-bearing). Two constraints, each shipped broken once:
  - The glob **must never match `init.*.zsh` or bare `omp.cache`** — `init.<hash>.zsh` is one stable-named file shared by every live shell with mtime never refreshed, so any mtime-sorted keep-N reaps it first — symptom `precmd:source: no such file or directory` on every prompt in every pane (`40c2f4b`). Reproduce: burst >50 shells, check the doomed slice for `init.*.zsh`.
  - The slice **must** be `"${(@)_c[51,-1]}"` — the unparenthesised form joins to one word and deletes nothing (shipped broken, grew 8.5k files).
- **Ghostty `shell-integration-features` is ADDITIVE over defaults** — source `cursor,sudo`; effective `cursor,sudo,title,no-ssh-env,no-ssh-terminfo,path` (only non-default delta: `no-sudo`→`sudo`). Verify with `ghostty +show-config`, never the source line. **Never set `no-path`** — it strips Ghostty's app dir from PATH and the `ghostty` command vanishes.
- **`set -g detach-on-destroy off`** — park/unpark UX; client stays attached when the current session dies.
- **Session persistence is intentionally manual** — `park-session.sh`/`unpark-session.sh`, no auto-restore. `save-session.sh` + `session-lib.sh` deleted in `4f12a1f` (write-only) — do not re-add.
- **Switcher/menu use `#{session_id}`, not `#{session_name}`** — names can carry quotes that break `display-menu` escaping; numeric `$N` IDs are quote-safe.

## Keybind layers

Five layers, outside-in: Aerospace (WM) → Ghostty (terminal) → tmux (multiplexer) → zsh (shell) → neovim (editor). Each layer claims a modifier band; a layer only intercepts what it explicitly binds, everything else falls through to the next.

- **Aerospace**: `ctrl-alt(-shift)` — WM-level, never reaches the terminal.
- **Ghostty**: `keybind =` in `config.ghostty` — global quick-terminal (`ctrl+grave`), scrollback/opacity, `cmd+` macOS-native combos, plus the four `ctrl+shift+` rewrites below. Minimal by design; most binds pushed down to tmux so they work over SSH too.
- **tmux**: `M-` (Alt) root table, prefix-free (`keybinds.conf`) + `copy-mode-vi` table (`copy-mode.conf`). Dual-encoding and `BTab` nuances: see Rules above.
- **zsh**: emacs mode (`bindkey -e`) + `Ctrl` word/line editing in `.zshrc` (`W`/`E` delete-back/accept-forward, `A`/`S` jump back/forward, `+Shift` widens word→line); `^z` toggles into `vicmd` for one command.
- **neovim**: `<leader>` (snacks pickers, `which-key.lua`), `<A-H/J/K/L>` for smart-splits pane nav — shares the M-H/J/K/L band with tmux, see below.

Nuance not covered by the Rules list: **M-H/J/K/L is shared, not layered.** tmux's root table checks `@pane-is-vim` per keypress (`if -F "#{@pane-is-vim}" "send-keys M-H" "select-pane -L"`) and forwards to neovim's own `<A-H/J/K/L>` (`smart-splits.lua`) when the active pane is vim, else runs `select-pane` itself. One binding, two consumers, arbitrated per-keypress at runtime — not a tmux-then-nvim fallthrough chain. Same pattern repeats in `copy-mode.conf`'s `copy-mode-vi` table.

## Cross-Tool Integration

- **tmux ↔ neovim**: `M-H/J/K/L` via `@pane-is-vim` (smart-splits.nvim).
- **tmux ↔ zsh**: nothing — the exit-code/status-dot wiring was removed (consumer deleted in `9b4f131`); restore recipe in `ARCHI.md` §9.
- **tmux ↔ ghostty**: terminal features (hyperlinks, clipboard, no extkeys) + `macos-option-as-alt`; `terminal-features` reset with `set -su` before appending to avoid reload duplicates.
- **zsh ↔ yazi**: `C-f` widget; `y()` wrapper cd-on-exit via temp cwd file.

## Validation

- Ghostty: `ghostty +show-config`.
- tmux: `tmux source-file ~/.config/tmux/tmux.conf` reloads the **running** server — the point. **`-f` does not change the socket** (that's `-L`/`-S`), so `tmux -f /dev/null start-server … kill-server` attaches to the live socket and destroys every session (it did, 2026-08-01). Parse-check on a throwaway socket: `tmux -L cfgcheck -f /dev/null start-server \; source-file ~/.config/tmux/tmux.conf \; kill-server`.
- Dotfiles: `home check` (health) · `home sync`.
- Shell scripts: `shellcheck` (advisory — zsh unsupported, SC1071 expected).
