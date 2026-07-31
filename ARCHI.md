# Architecture — shell, terminal & editor rig

Living document. Covers the **public** half of the dotfiles: zsh, tmux, ghostty, nvim, and the cross-tool wiring between them. The Claude Code / agent rig lives in the private half and is documented separately — see [`~/.dotfiles-private/ARCHI.md`](../.dotfiles-private/ARCHI.md).

Read this before changing config. It records *why* things are shaped the way they are, so a future edit doesn't undo a decision that was made for a reason.

## 0. Which document owns what

Three docs, non-overlapping. Keep it that way or they drift.

| Doc               | Owns                                                                   |
| ----------------- | ---------------------------------------------------------------------- |
| `README.md`       | Install, bootstrap, what this repo is for a stranger                   |
| `CLAUDE.md`       | Terse rules an agent must obey mid-edit — the non-obvious gotchas only |
| `ARCHI.md` (this) | Structure, load order, philosophy, rationale, removed-things           |

`CLAUDE.md` is the enforcement surface; this is the explanation surface. When a rule in `CLAUDE.md` needs a paragraph of justification, the paragraph belongs here and the rule stays one line there.

## 1. Repo split

Two chezmoi repos, split by **audit surface**, not by importance:

```
~/.dotfiles           public   shell, tmux, ghostty, nvim, git, terminal tooling
~/.dotfiles-private   private  agent rigs, secrets, ssh, aws, gnupg, npmrc
```

The public `.chezmoiignore` excludes `.claude` and `CLAUDE.md` so the private half is the sole source of truth for agent config. Anything that would be embarrassing or dangerous in a public GitHub repo goes private; everything else is public so it can be read, forked and criticised.

Both repos deploy into the same `$HOME`. A single logical config can therefore span both — the zsh setup does exactly this (`private.zsh` ships from the private repo into `$ZDOTDIR`). **Any move of a shared path needs a coordinated change in both repos**, or the source line breaks.

## 2. The deploy loop

chezmoi source is canonical. The runtime target is downstream and disposable.

```
edit source (~/.dotfiles/*)  →  home apply  →  validate with the tool's own validator  →  home re-add
```

`home` is the wrapper (`dot_bin/executable_home`) that drives both repos together. `home re-add` captures normalisation a tool applied to its own config back into source.

Two hazards that have bitten before:

- **chezmoi never prunes.** Deleting a source file leaves the deployed target in place forever, and nothing will ever flag it. After removing or moving a source file, `rm` the orphaned target by hand. Verify with `chezmoi source-path <target>` — if it errors, the file is unmanaged.

- **Validate before applying when the live shell depends on it.** A broken `$ZDOTDIR/.zshrc` plus a live stub is a broken login shell. Stage it first:

  ```sh
  chezmoi apply --destination "$STAGE" --source ~/.dotfiles
  ZDOTDIR="$STAGE/.config/zsh" zsh -i -c 'print -l $path; bindkey | grep "\^F"'
  ```

## 3. zsh layout — ZDOTDIR

All zsh config lives in `$XDG_CONFIG_HOME/zsh`. `$HOME` holds a two-line stub and nothing else.

```
~/.zshenv                     stub: sets ZDOTDIR, sources the real .zshenv
~/.config/zsh/.zshenv         environment, XDG vars, PATH composition
~/.config/zsh/.zshrc          interactive: prompt, plugins, completions, keybinds
~/.config/zsh/alias.zsh       aliases
~/.config/zsh/fzf.zsh         fzf options + theme
~/.config/zsh/private.zsh     ← ships from the PRIVATE repo
```

### The read-order trap

This is the one thing that will silently break everything, so it is worth stating precisely.

zsh reads `$ZDOTDIR/.zshenv` — but at that moment `ZDOTDIR` is not yet set, so it defaults to `$HOME` and zsh reads `~/.zshenv`. **It does not go back and re-read `$ZDOTDIR/.zshenv` once your stub sets `ZDOTDIR`.** Only `.zprofile`, `.zshrc` and `.zlogin` are picked up from the new location.

Probed, not assumed:

```
ZDOTDIR set in ~/.zshenv    →  $ZDOTDIR/.zshenv  NEVER read
                               $ZDOTDIR/.zprofile, .zshrc, .zlogin  read normally
```

So the stub must source it explicitly:

```zsh
export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
[[ -r "$ZDOTDIR/.zshenv" ]] && source "$ZDOTDIR/.zshenv"
```

Verified across all four modes — `zsh -c`, `zsh -i -c`, `zsh -l -i -c`, and plain non-interactive. The non-interactive case is the load-bearing one: without it, scripts, `ssh host cmd` and editor subshells lose PATH entirely.

`.zprofile` does not exist. It was a pure placeholder with no content; macOS `/etc/zprofile` already runs `path_helper` for login shells. Do not re-add an empty one.

### PATH composition

PATH is built **once**, in `.zshenv`, in a deliberate order, and deduplicated at the end:

```
Homebrew  →  language toolchains (cargo, go)  →  ~/.local/bin, ~/.bin  →  typeset -U PATH path
```

Homebrew must precede `/usr/bin` so its binaries beat the system ones. Local bins go last so they override everything. `typeset -U` collapses duplicates while **preserving first-occurrence order** — which means re-exporting an existing entry later *reorders* it rather than being a no-op. Do not "clean up" an apparently redundant PATH export without diffing `print -l $path` before and after.

`fnm` is the exception: it must load in `.zshrc` *after* Homebrew, so fnm-managed Node beats Homebrew's Node.

### XDG variables

`XDG_CONFIG_HOME`, `XDG_CACHE_HOME`, `XDG_DATA_HOME` and `XDG_STATE_HOME` are all set explicitly in `.zshenv`. Derive from them; don't hardcode `~/.local/share` or `~/.config` in downstream config.

macOS has no `XDG_RUNTIME_DIR`. Ephemeral state (PID files, session markers) goes in `$XDG_STATE_HOME` — the pragmatic choice, not the spec-pure one. Don't "fix" this.

## 4. Startup philosophy

**zsh startup is intentionally synchronous.** No plugin manager, no `zsh-defer`, no eval caching.

This is a deliberate trade and it gets re-litigated by every optimisation guide on the internet, so: plugins are plain git clones in `$XDG_DATA_HOME/zsh/plugins`, cloned by a loop in `.zshrc` and updated with `zsh-plugin-update`. Tool integrations are direct `eval "$(tool init zsh)"`.

Deferral buys milliseconds and costs determinism — a deferred plugin that loads after your first keystroke produces bindings that exist or don't depending on how fast you type. That is a worse failure mode than a slower start.

**Budget: warm start under ~200ms.** Measure, don't guess:

```sh
for i in 1 2 3 4 5; do /usr/bin/time -p zsh -i -c exit; done
ZPROF=true zsh -i -c exit          # per-function breakdown
```

Anything proposing zinit / zsh-defer / eval-caching to get under this is rejected by default.

### Load order inside `.zshrc`

Order is load-bearing. The failure mode of getting it wrong is a *silently missing keybinding*, not an error.

```
options & history  →  keybindings (bindkey -e)  →  prompt (OMP)  →  plugin clone loop
   →  fzf  →  fpath  →  compinit  →  fzf-tab  →  widget-wrapping plugins
   →  tool integrations  →  aliases & functions  →  fnm
```

Two constraints worth naming:

- `fzf-tab` must load **after** `compinit` and **before** any plugin that wraps widgets (`fast-syntax-highlighting`, `zsh-autosuggestions`).
- `functions.sh` sources `keybindings.sh`, which binds `C-f` to the yazi widget. It is sourced late, after the widget-wrapping plugins. Move it earlier and `C-f` dies silently.

Regression check after any reordering — compare against a pre-change capture:

```sh
zsh -i -c 'bindkey' > after.txt && diff before.txt after.txt
```

`bindkey` is the diff that catches real load-order breakage. `$path` and `$fpath` catch the rest.

## 5. Completions

- Static completions live in `~/.zfunc`, generated by `update-completions` and autoloaded via `compinit`. They are never `eval`'d at startup.
- Re-run `update-completions` after upgrading `gh`, `op`, `bd` or `wrangler`.
- `compinit` uses a 24-hour cache check: full security scan once a day, `-C` fast path otherwise.

## 6. Cross-tool integration

| Wiring         | Mechanism                                                                          |
| -------------- | ---------------------------------------------------------------------------------- |
| tmux ↔ nvim    | `M-H/J/K/L` forwarded via `@pane-is-vim` (needs smart-splits.nvim)                 |
| tmux ↔ zsh     | `_tmux_exit_code` precmd → `@last_exit_code` window option → status bar error dot  |
| tmux ↔ ghostty | terminal features (hyperlinks, clipboard — **no** extkeys) + `macos-option-as-alt` |
| zsh ↔ yazi     | `C-f` widget opens yazi; `y()` wrapper handles cd-on-exit via temp cwd file        |
| zsh ↔ atuin    | `C-r` is atuin, not fzf (`--disable-up-arrow`)                                     |

Hard-won details:

- **`_tmux_exit_code` must be the first precmd** — it captures `$?` before OMP modifies it.
- **`keybinds.conf` ↔ `keyb.yml` must stay in sync.** Always update both.
- **tmux names Shift-Tab `BTab`** (`M-BTab`), not `M-S-Tab`.
- **Dual keybindings for Alt+Shift.** Bind both `M-S-D` (CSI u) and `M-D` (legacy). Ghostty 1.3.0+ (#9406) strips Shift from Option-modified keys on macOS in modifyOtherKeys mode. `extkeys` is deliberately omitted from `terminal-features` to keep Ghostty in legacy mode where case survives.
- **`terminal-features` must be reset with `set -su`** before appending, or it duplicates on reload.
- **Emacs mode is the default** (`bindkey -e`), `C-z` toggles vi — required for Alt binds without lag.
- **`set -g detach-on-destroy off`** — needed for park/save/unpark; keeps the client attached.
- **Switcher/menu use `#{session_id}`, not `#{session_name}`** — names can contain quotes that break shell escaping in `display-menu`; numeric `$N` IDs are quote-safe.
- **Popup scripts live in `dot_config/tmux/scripts/`**, not `dot_bin/`.
- Session persistence is **intentionally manual** — park/save/unpark, no resurrect/continuum, no auto-restore on boot.

## 7. Shell function conventions

Functions live in `dot_bin/*.sh`, sourced by `functions.sh`, deployed to `~/.bin/`.

- Internal functions are prefixed `_mrgsh_`; user-facing names are exposed as aliases or plain function names.
- Guard optional tools with `can_haz <tool> &&` — an alias for a missing binary is dead config, and an *unguarded* one is a broken command waiting to be typed.
- Multi-tool functions declare dependencies up front via `_mrgsh_check_tools`.
- Files sourced for side effects use plain `.sh` names; only genuinely executable scripts get the `executable_` chezmoi prefix.

### `awake`

Wraps `caffeinate -dims`. Detached by design — it writes `pid<TAB>deadline<TAB>spec` to `$XDG_STATE_HOME/awake/session` and is managed with `awake off` / `awake status`.

```
awake        8h default        awake 30m    minutes, 1–59
awake 2h     hours, 1–24       awake off    release
                               awake status remaining
```

A bare number (`awake 3`) is rejected on purpose — the ambiguity between 3 hours and 3 minutes is not worth a convenience.

Two implementation notes worth preserving:

- Write the state file with `printf`, **not** `print -r`. `print -r` is raw and does not expand `\t`, which silently produces a single unsplittable field and breaks `off`/`status` entirely.
- Liveness is checked with `ps -p <pid> -o comm=` matching `*caffeinate`, not bare `kill -0`. **Known limit:** a recycled PID landing on *any* caffeinate process would let `off` kill a foreign assertion. Other tools do run caffeinate on this machine, so this is a real if unlikely edge.

## 8. Validation

| Target          | Command                                                               |
| --------------- | --------------------------------------------------------------------- |
| Ghostty         | `ghostty +show-config`                                                |
| tmux            | `tmux source-file ~/.config/tmux/tmux.conf`                           |
| zsh             | `zsh -i -c exit` then diff `bindkey` / `$path` / `$fpath` vs baseline |
| Dotfiles health | `home check`                                                          |
| Dotfiles sync   | `home sync`                                                           |
| Shell scripts   | `shellcheck` — advisory only                                          |

`shellcheck` does not support zsh and emits **SC1071 on every zsh file**. That is expected, not a regression. It still catches real quoting bugs in the POSIX-ish subset, so it stays wired in as advisory.

## 9. Removed — do not re-add

Each of these was deliberately deleted. Re-adding one means re-litigating the reason.

| Removed                         | Why                                                                                                                                                                                                                                                                        |
| ------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/tmp/.zsh_editor_cache_$UID`   | Cached `$EDITOR` via a predictable path in a world-writable dir, then fed it to `GIT_EDITOR` — a value later executed as a command. Saved no measurable time. `EDITOR` is now a literal.                                                                                   |
| `~/.fzf.zsh` loader             | Unmanaged, generated by fzf's install script, hardcoded `/opt/homebrew/opt/fzf/shell/*`. Replaced by `eval "$(fzf --zsh)"` — verified byte-identical in content, differing only in ordering. Its PATH addition was redundant; `fzf-tmux` resolves via `/opt/homebrew/bin`. |
| Linux Homebrew branch           | `DOT_TARGET` was hardcoded `"macos"`, so the branch was unreachable. This rig is macOS-only.                                                                                                                                                                               |
| `mysql-client` PATH block       | Neither the directory nor the `mysql` binary exists.                                                                                                                                                                                                                       |
| `~/bin` PATH entry              | Directory does not exist; `~/.bin` is the real one.                                                                                                                                                                                                                        |
| pyenv block                     | Already commented out, and `~/.pyenv` absent.                                                                                                                                                                                                                              |
| Empty `.zprofile`               | Pure placeholder. macOS `/etc/zprofile` handles login-shell `path_helper`.                                                                                                                                                                                                 |
| zinit / zsh-defer / eval caches | See §4. Determinism over milliseconds.                                                                                                                                                                                                                                     |
| tmux-resurrect / continuum      | Session persistence is manual by choice.                                                                                                                                                                                                                                   |

## 10. Patterns worth keeping

Distilled from auditing this repo. These generalise.

1. **Probe, don't infer.** Every claim in this document that could be wrong was checked with a command. "The config sets X" is proven by running the shell and reading X back, not by reading the file that appears to set it.
1. **Adjacent evidence is not evidence.** A plausible path, a config key, or a nearby line proves only its own existence. Probe the exact assertion.
1. **Guard optional tools, or delete them.** An unguarded alias to a missing binary is a broken command. A guarded alias to a binary you no longer install is dead config. Both are worth finding.
1. **Dead config is a cost.** Every unreachable branch is something a future reader must understand before they can change anything nearby. Delete on sight; git remembers.
1. **Load order is the real fragility in a shell rig.** Path typos error loudly; a keybinding that silently stops existing does not. Diff `bindkey` after any reordering.
1. **Derive paths from XDG vars.** An XDG-shaped path with no XDG variable behind it is the worst of both — the appearance of a convention without the substance.
1. **A refactor that makes the file harder to read is a regression**, however much duplication it removes. Simple and obvious beats clever and DRY.
1. **Measure before optimising, and record the number.** A budget with no measurement is folklore.

## 11. References

- Private half: [`~/.dotfiles-private/ARCHI.md`](../.dotfiles-private/ARCHI.md)
- Agent rules: `~/.claude/rules/`
- chezmoi: <https://www.chezmoi.io/reference/>
- zsh startup files: `man zshall`, section *STARTUP/SHUTDOWN FILES*
