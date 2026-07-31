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

### Repo docs must not deploy

`README.md`, `CLAUDE.md`, `ARCHI.md` and `AGENTS.md` are *documentation about the repo*, not dotfiles. Every one must be listed in `.chezmoiignore` or chezmoi will happily deploy it into `$HOME`.

This is easy to get wrong and hard to notice, because **`.gitignore` does not protect you** — chezmoi reads the source directory, not git's index. `AGENTS.md` was globally gitignored (so it never reached GitHub) yet still deployed to `~/AGENTS.md` from *both* repos for exactly that reason.

The global agent kernels are the files that *should* deploy, and they live beside each other:

```
~/.claude/CLAUDE.md   ←  ~/.dotfiles-private/dot_claude/CLAUDE.md
~/.codex/AGENTS.md    ←  UNMANAGED by either repo  (known gap)
```

`~/.codex/AGENTS.md` having no source of truth is a real gap, recorded here rather than quietly tolerated.

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

**Measured 2026-07-31: median 190ms, range 170–200ms (n=15).**

`CLAUDE.md` previously carried a "~155ms" budget. That number is **unexplained** — it was not reproduced at the time of this measurement, and no profile of the older config survives to say where the 35ms went. It is recorded here as an open question, not silently restated as the new truth. If you care about the gap, profile before assuming a regression: the delta may be new plugins, a slower disk, or a number that was optimistic to begin with.

Where the time actually goes, per `zprof`:

```
compinit + compaudit  ~24ms      the single largest attributable cost
everything else       <3ms each  fsh widget binding, fzf-tab, can_haz x16
```

That accounts for roughly a third of wall clock; the rest is process spawn plus `eval "$(tool init)"` subshells, which `zprof` does not attribute to zsh functions.

Measure, don't guess:

```sh
for i in $(seq 15); do /usr/bin/time -p zsh -i -c exit; done   # wall clock
ZPROF=true zsh -i -c exit                                      # per-function breakdown
```

Anything proposing zinit / zsh-defer / eval-caching to get under this is rejected by default — see the trade above.

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
| tmux ↔ zsh     | `_tmux_exit_code` precmd → `@last_exit_code` window option (see caveat below)      |
| tmux ↔ ghostty | terminal features (hyperlinks, clipboard — **no** extkeys) + `macos-option-as-alt` |
| zsh ↔ yazi     | `C-f` widget opens yazi; `y()` wrapper handles cd-on-exit via temp cwd file        |
| zsh ↔ atuin    | `C-r` is atuin, not fzf (`--disable-up-arrow`)                                     |

`CLAUDE.md` carries the enforceable one-line form of these rules — that is the list to obey while editing. What follows is the *why*, which is this document's job. Do not restate a bare rule here without adding rationale; that is how the two docs drift.

- **Alt+Shift needs dual bindings** (`M-S-D` *and* `M-D`). Ghostty 1.3.0+ ([#9406]) strips the Shift modifier from Option-modified keys on macOS when in modifyOtherKeys mode. `extkeys` is therefore deliberately **omitted** from `terminal-features`, keeping Ghostty in legacy mode where case is preserved (`M-d` vs `M-D`). Adding `extkeys` for its other benefits will silently break every Alt+Shift bind.

- **`terminal-features` is reset with `set -su` before appending** because tmux config reload is not idempotent — without the reset, features accumulate duplicates on every source.

- **Emacs mode is the default** (`bindkey -e`) rather than vi, with `C-z` to toggle. vi mode introduces a mode-switch delay that makes Alt keybinds feel laggy; the toggle keeps vi available without paying for it on every keystroke.

- **Switcher/menu use `#{session_id}`, not `#{session_name}`.** Session names can contain apostrophes and quotes, which break shell-style escaping inside `display-menu` command strings. Numeric `$N` IDs are quote-safe by construction.

- **`_tmux_exit_code` is the first precmd** because it must read `$?` before OMP's own precmd overwrites it. Order here is the entire mechanism, not a preference. **It must also capture `$?` into a local as the function's very first statement** — this form is silently broken:

  ```zsh
  _tmux_exit_code() { [[ -n "$TMUX" ]] && tmux set-option -qw @last_exit_code $?; }   # always 0
  ```

  `$?` is expanded *after* the `[[ ]]` test has run, so it records the test's status, not the command's. Being first in `precmd_functions` is necessary but not sufficient. Correct form:

  ```zsh
  _tmux_exit_code() { local ec=$?; [[ -n "$TMUX" ]] && tmux set-option -qw @last_exit_code "$ec"; }
  ```

  **Known gap:** nothing currently *reads* `@last_exit_code`. Three shells set it (zsh, bash, and formerly nushell) and no tmux config consumes it — the "status bar error dot" this was built for was never implemented. Either wire a `status-right` segment on `#{@last_exit_code}` or drop the producers; do not leave it as a documented feature that does not exist.

- **Session persistence is deliberately manual** (park/save/unpark, no resurrect/continuum). Auto restore-on-boot resurrects panes whose working directories and processes have moved on, which is worse than starting clean.

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

| Removed                            | Why                                                                                                                                                                                                                                                                        |
| ---------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/tmp/.zsh_editor_cache_$UID`      | Cached `$EDITOR` via a predictable path in a world-writable dir, then fed it to `GIT_EDITOR` — a value later executed as a command. Saved no measurable time. `EDITOR` is now a literal.                                                                                   |
| `~/.fzf.zsh` loader                | Unmanaged, generated by fzf's install script, hardcoded `/opt/homebrew/opt/fzf/shell/*`. Replaced by `eval "$(fzf --zsh)"` — verified byte-identical in content, differing only in ordering. Its PATH addition was redundant; `fzf-tmux` resolves via `/opt/homebrew/bin`. |
| Linux Homebrew branch              | `DOT_TARGET` was hardcoded `"macos"`, so the branch was unreachable. This rig is macOS-only.                                                                                                                                                                               |
| `mysql-client` PATH block          | Neither the directory nor the `mysql` binary exists.                                                                                                                                                                                                                       |
| `~/bin` PATH entry                 | Directory does not exist; `~/.bin` is the real one.                                                                                                                                                                                                                        |
| pyenv block                        | Already commented out, and `~/.pyenv` absent.                                                                                                                                                                                                                              |
| Empty `.zprofile`                  | Pure placeholder. macOS `/etc/zprofile` handles login-shell `path_helper`.                                                                                                                                                                                                 |
| zinit / zsh-defer / eval caches    | See §4. Determinism over milliseconds.                                                                                                                                                                                                                                     |
| tmux-resurrect / continuum         | Session persistence is manual by choice.                                                                                                                                                                                                                                   |
| `dot_bin/search.sh` (`rgs`, `fds`) | Both wrapped `tv` (television), which is not installed — the commands errored on every invocation. `fzf`, `fd`, `rg` and the `C-f` yazi widget already cover this ground.                                                                                                  |
| `alias azvms`                      | `az` not installed, and the alias was **unguarded** — a broken command waiting to be typed. `dovms` beside it is now `can_haz doctl`-guarded.                                                                                                                              |
| `alias d=lazydocker`               | `lazydocker` not installed. Guarded, so it failed silently — pure dead weight.                                                                                                                                                                                             |
| `wt-dev` / `w` dev-build block     | Pointed at `~/DEV/rd/wt/main/bin/wt`, which no longer exists. The released `wt` is installed and wired separately.                                                                                                                                                         |
| `dot_config/nushell/`              | `nu` not installed, zero references in either repo — 8.5K of config for a shell that never runs.                                                                                                                                                                           |
| `~/.fzf/`                          | A 1.6M git clone left by fzf's manual install script (Jan 2024). Unreferenced; fzf comes from Homebrew.                                                                                                                                                                    |

Two lessons worth generalising from that list:

- **A vendor install script that writes into `$HOME` creates state neither repo owns.** chezmoi will never surface it and nothing will ever flag it. Prefer package-manager installs and `tool --init`-style generated output, so config stays *derivable* rather than *deposited*.
- **An unguarded alias to a missing binary is a bug; a guarded one is dead weight.** Both are worth finding, but only the first will bite you. Audit with a loop over every tool an alias references — `command -v` each one — rather than reading the file and assuming.

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

[#9406]: https://github.com/ghostty-org/ghostty/pull/9406
