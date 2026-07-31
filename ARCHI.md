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

The global agent kernels are the files that *should* deploy:

```
~/.claude/CLAUDE.md   ←  ~/.dotfiles-private/dot_claude/CLAUDE.md
~/.config/AGENTS.md   ←  ~/.dotfiles-private/dot_config/AGENTS.md      canonical
```

**`~/.config/AGENTS.md` is deliberately tool-neutral.** The AGENTS.md spec itself defines *no* user-level location — it is strictly repo-root and nested-directory scoped. But tool vendors converged on `~/.config/…` independently, even on macOS where the native convention would be `~/Library/Application Support/`:

| tool        | global path                                                               |
| ----------- | ------------------------------------------------------------------------- |
| Amp         | `~/.config/amp/AGENTS.md` **and bare `~/.config/AGENTS.md`**              |
| opencode    | `~/.config/opencode/AGENTS.md`                                            |
| Zed         | `~/.config/zed/AGENTS.md`                                                 |
| Codex       | `~/.codex/AGENTS.md` (relocatable via `CODEX_HOME`)                       |
| Aider       | none native — needs `~/.aider.conf.yml` `read:` with an **absolute** path |
| Cursor      | no global AGENTS.md path documented at all                                |
| Claude Code | `~/.claude/CLAUDE.md` — reads `CLAUDE.md`, never `AGENTS.md`              |

Bare `~/.config/AGENTS.md` is the only location any tool reads without a vendor subdirectory, so it is the canonical file. **No tool-specific symlinks exist today.** Note `opencode` *is* installed (`/opt/homebrew/bin/opencode`) with live unmanaged config at `~/.config/opencode/` — so it is the one tool that would benefit from a link right now. Add per tool on adoption:

```sh
ln -s ../.config/AGENTS.md ~/.config/opencode/AGENTS.md
```

**Symlink targets are relative to the symlink's own directory, not `$HOME`.** From a vendor subdirectory the target must be `../.config/AGENTS.md`; a bare `.config/AGENTS.md` would resolve to `<vendordir>/.config/AGENTS.md` and dangle. (`~/.prettierignore → .config/git/ignore` works only because it sits directly in `$HOME`.)

Symlink support is *evidenced* only for Claude Code (officially documented recipe) and Codex. For opencode, Zed, Amp and Gemini CLI it is untested — verify when you adopt one, don't assume.

Corollary, learned the hard way: **do not pre-create vendor directories for tools you have not installed.** A symlink farm for six agents you don't run is exactly the dead config this rig exists to avoid. One canonical file, links added on adoption.

## 2. The deploy loop

chezmoi source is canonical. The runtime target is downstream and disposable.

```
edit source (~/.dotfiles/*)  →  home apply  →  validate with the tool's own validator  →  home re-add
```

`home` is the wrapper (`dot_bin/executable_home`) that drives both repos together. `home re-add` captures normalisation a tool applied to its own config back into source.

Two hazards that have bitten before:

- **chezmoi never prunes — by default.** Deleting a source file leaves the deployed target in place forever, and nothing will ever flag it. After removing or moving a source file, `rm` the orphaned target by hand. Verify with `chezmoi source-path <target>` — if it errors, the file is unmanaged.

  There are two first-class fixes, both verified on v2.71.1:

  | mechanism        | effect                                                                |
  | ---------------- | --------------------------------------------------------------------- |
  | `exact_<dir>`    | chezmoi **deletes** any unmanaged file in that directory on apply     |
  | `.chezmoiremove` | newline-separated list of targets to delete; works for files and dirs |

  `exact_` is the durable answer and this repo does not use it yet. The caveat is real though: anything a *tool* writes into that directory gets deleted too, so audit for runtime-written files before converting a directory. Tracked for the single-repo migration.

- **`.gitignore` does not gate chezmoi.** It reads the source directory, not git's index. A file can be gitignored — never reaching GitHub — and still deploy into `$HOME` on every apply. Use `.chezmoiignore` for "do not deploy"; they are unrelated mechanisms.

- **Validate before applying when the live shell depends on it.** A broken `$ZDOTDIR/.zshrc` plus a live stub is a broken login shell. Stage it first:

  ```sh
  chezmoi apply --destination "$STAGE" --source ~/.dotfiles
  ZDOTDIR="$STAGE/.config/zsh" zsh -l -i -c 'print -l $path; bindkey | grep "\^F"'
  ```

## 3. zsh layout — ZDOTDIR

All zsh config lives in `$XDG_CONFIG_HOME/zsh`. `$HOME` holds a two-line stub and nothing else.

```
~/.zshenv                     stub: sets ZDOTDIR, sources the real .zshenv
~/.config/zsh/.zshenv         environment, XDG vars; calls _mrgsh_compose_path
~/.config/zsh/.zprofile       re-asserts PATH after macOS path_helper (login shells)
~/.config/zsh/path.zsh        PATH composition, single source of truth
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

`.zprofile` **does exist and is load-bearing** — see the `path_helper` trap below. It was once an empty placeholder and was deleted as dead weight; that was wrong, and re-creating it with real content is what makes Homebrew outrank `/usr/bin` in a login shell. Do not delete it again.

### PATH composition, and the `path_helper` trap

**This is the single most misunderstood part of the rig. Read it before touching PATH.**

macOS `/etc/zprofile` runs `/usr/libexec/path_helper`, which does **not** append politely. It:

1. emits `/etc/paths` first — `/usr/local/bin`, `/usr/bin`, `/bin`, `/usr/sbin`, `/sbin`
1. then every fragment in `/etc/paths.d/*` (Homebrew's own fragment lands here, sorted **last**)
1. then appends whatever was already in `$PATH` — **at the tail**

So anything `.zshenv` carefully arranged gets demoted. Measured, login shell, before the fix:

```
usrlocal=2   usrbin=4   ...   brew=17   dotbin=18   localbin=19
```

`/usr/bin` beating Homebrew is exactly what the config was trying to prevent, and `~/.bin` — meant to override everything — ended up dead last.

**The fix is `.zprofile`, and this is precisely what `.zprofile` is for on macOS.** It is the only user file that runs *after* `/etc/zprofile`. PATH composition therefore lives in one file, `path.zsh`, sourced from **both**:

```
~/.zshenv  →  $ZDOTDIR/.zshenv  →  path.zsh::_mrgsh_compose_path   (non-login shells)
              /etc/zprofile     →  path_helper reorders everything
              $ZDOTDIR/.zprofile → path.zsh::_mrgsh_compose_path   (re-assert, login shells)
```

`_mrgsh_compose_path` prepends each directory that exists, then `typeset -gU PATH path` dedupes. Prepending an entry that is already present **reorders** it rather than being a no-op — that is the mechanism, not a side effect. It is idempotent, so running it twice is safe and correct.

Result, all three modes:

| mode                | `~/.bin` | `~/.local/bin` | brew | `/usr/local/bin` | `/usr/bin` |
| ------------------- | -------- | -------------- | ---- | ---------------- | ---------- |
| login + interactive | 2        | 3              | 6    | 8                | 10         |
| interactive         | 2        | —              | 6    | —                | 11         |
| non-interactive     | 1        | —              | 5    | —                | 10         |

**Never verify a PATH change with `zsh -i -c` alone.** That is a non-login shell, so `/etc/zprofile` never runs and `path_helper` never fires — the exact bug above is invisible. Always test all three:

```sh
for m in "-l -i" "-i" ""; do zsh $=m -c 'print "brew=${path[(i)/opt/homebrew/bin]} usrbin=${path[(i)/usr/bin]}"'; done
```

An earlier audit of this repo concluded a Homebrew re-prepend in `.zshrc` was "redundant and harmful" — measured only in a non-login shell. It was in fact a workaround for `path_helper`; deleting it broke login shells silently. The workaround was in the wrong file, not wrong.

`fnm` is the remaining exception: it loads in `.zshrc` *after* Homebrew, so fnm-managed Node wins.

### XDG variables

`XDG_CONFIG_HOME`, `XDG_CACHE_HOME`, `XDG_DATA_HOME` and `XDG_STATE_HOME` are all set explicitly in `.zshenv`. Derive from them; don't hardcode `~/.local/share` or `~/.config` in downstream config.

macOS has no `XDG_RUNTIME_DIR`. Ephemeral state (PID files, session markers) goes in `$XDG_STATE_HOME` — the pragmatic choice, not the spec-pure one. Don't "fix" this.

## 4. Startup philosophy

**zsh startup is intentionally synchronous.** No plugin manager, no `zsh-defer`, no eval caching.

This is a deliberate trade and it gets re-litigated by every optimisation guide on the internet, so: plugins are plain git clones in `$XDG_DATA_HOME/zsh/plugins`, cloned by a loop in `.zshrc` and updated with `zsh-plugin-update`. Tool integrations are direct `eval "$(tool init zsh)"`.

Deferral buys milliseconds and costs determinism — a deferred plugin that loads after your first keystroke produces bindings that exist or don't depending on how fast you type. That is a worse failure mode than a slower start.

**Measured 2026-08-01: median 123ms, range 121–134ms (n=15).**

The earlier "190ms (n=15)" and the "~155ms" before it were both recorded when the `compinit` fast path was silently unreachable — `[[ -n ~/.zcompdump(#qN.mh+24) ]]` used a `(#q…)` qualifier while `EXTENDED_GLOB` was off, so the test was a non-empty literal, always true, and **every** shell paid a full `compinit` plus `compaudit`. Making the branch reachable (array form with bare glob qualifiers, which need no `EXTENDED_GLOB`) took `compinit` from ~24ms to 8.4ms and removed `compaudit` entirely. Measure with `ZPROF=true zsh -i -c true` before assuming a regression.

Where the time actually goes, per `zprof`:

```
compinit              8.4ms     still the single largest attributable cost
enable-fzf-tab        2.9ms
_zsh_highlight_bind_widgets  2.9ms
everything else       <1ms each  can_haz x15, add-zsh-hook x8, compdef x10
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

Three constraints worth naming:

- `fzf-tab` must load **after** `compinit` and **before** any plugin that wraps widgets (`fast-syntax-highlighting`, `zsh-autosuggestions`).
- `functions.sh` sources `keybindings.sh`, which binds `C-f` to the yazi widget. It is sourced late, after the widget-wrapping plugins. Move it earlier and `C-f` dies silently.
- **`C-r` belongs to atuin only because atuin loads last.** `fzf --zsh` and `atuin init zsh` both bind it unconditionally — fzf to `fzf-history-widget`, atuin to `atuin-search`. `--disable-up-arrow` governs only `^[[A`, not `^R`. Swap the two `eval` lines and `C-r` reverts to fzf with no error.

Regression check after any reordering — compare against a pre-change capture:

```sh
zsh -i -c 'bindkey' > after.txt && diff before.txt after.txt
```

`bindkey` is the diff that catches real load-order breakage. `$path` and `$fpath` catch the rest.

## 5. Completions

- Static completions live in `~/.zfunc`, generated by `update-completions` and autoloaded via `compinit`. They are never `eval`'d at startup.
- Re-run `update-completions` after upgrading `gh`, `op` or `wrangler`.
- `compinit` uses a 24-hour cache check: full security scan once a day, `-C` fast path otherwise.

## 6. Cross-tool integration

| Wiring         | Mechanism                                                                          |
| -------------- | ---------------------------------------------------------------------------------- |
| tmux ↔ nvim    | `M-H/J/K/L` forwarded via `@pane-is-vim` (needs smart-splits.nvim)                 |
| tmux ↔ zsh     | *(removed — see §9; the exit-code indicator had no consumer)*                      |
| tmux ↔ ghostty | terminal features (hyperlinks, clipboard — **no** extkeys) + `macos-option-as-alt` |
| zsh ↔ yazi     | `C-f` widget opens yazi; `y()` wrapper handles cd-on-exit via temp cwd file        |
| zsh ↔ atuin    | `C-r` is atuin, not fzf (`--disable-up-arrow`)                                     |

`CLAUDE.md` carries the enforceable one-line form of these rules — that is the list to obey while editing. What follows is the *why*, which is this document's job. Do not restate a bare rule here without adding rationale; that is how the two docs drift.

- **Alt+Shift needs dual bindings** (`M-S-D` *and* `M-D`). Ghostty 1.3.0+ ([#9406]) strips the Shift modifier from Option-modified keys on macOS when in modifyOtherKeys mode. `extkeys` is therefore deliberately **omitted** from `terminal-features`, keeping Ghostty in legacy mode where case is preserved (`M-d` vs `M-D`). Adding `extkeys` for its other benefits will silently break every Alt+Shift bind.

- **`terminal-features` is reset with `set -su` before appending** because tmux config reload is not idempotent — without the reset, features accumulate duplicates on every source.

- **Emacs mode is the default** (`bindkey -e`) rather than vi, with `C-z` to toggle. vi mode introduces a mode-switch delay that makes Alt keybinds feel laggy; the toggle keeps vi available without paying for it on every keystroke.

- **Switcher/menu use `#{session_id}`, not `#{session_name}`.** Session names can contain apostrophes and quotes, which break shell-style escaping inside `display-menu` command strings. Numeric `$N` IDs are quote-safe by construction.

- **If you ever re-add a `$?`-capturing precmd, capture into a local as the first statement.** This form looks right and is silently always-zero:

  ```zsh
  _tmux_exit_code() { [[ -n "$TMUX" ]] && tmux set-option -qw @last_exit_code $?; }   # always 0
  ```

  `$?` is expanded *after* the `[[ ]]` test runs, so it records the test's status. The correct shape is `local ec=$?` on line one, then use `"$ec"`. Position in `precmd_functions` is **irrelevant** — zsh restores `$?` and `pipestatus` to the true last-command values before invoking *each* hook function (verified on zsh 5.9 and 5.9.2; OMP's own `_omp_precmd` registers last and still reads `$?` correctly). Do not prepend a hook believing it must run first. See §9 for why the real one was removed.

- **Session persistence is deliberately manual** (park/unpark, no resurrect/continuum; `save-session.sh` deleted in `4f12a1f`). Auto restore-on-boot resurrects panes whose working directories and processes have moved on, which is worse than starting clean.

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

| Target           | Command                                                          |
| ---------------- | ---------------------------------------------------------------- |
| Ghostty          | `ghostty +show-config`                                           |
| tmux             | `tmux source-file ~/.config/tmux/tmux.conf`                      |
| zsh — load order | `zsh -i -c exit` then diff `bindkey` / `$fpath` vs baseline      |
| zsh — PATH       | three-mode loop from §3; **`-i` alone hides `path_helper` bugs** |
| Dotfiles health  | `home check`                                                     |
| Dotfiles sync    | `home sync`                                                      |
| Shell scripts    | `shellcheck` — advisory only                                     |

`shellcheck` does not support zsh and emits **SC1071 on every zsh file**. That is expected, not a regression. It still catches real quoting bugs in the POSIX-ish subset, so it stays wired in as advisory.

## 9. Removed — do not re-add

Each of these was deliberately deleted. Re-adding one means re-litigating the reason.

| Removed                                    | Why                                                                                                                                                                                                                                                                                   |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/tmp/.zsh_editor_cache_$UID`              | Cached `$EDITOR` via a predictable path in a world-writable dir, then fed it to `GIT_EDITOR` — a value later executed as a command. Saved no measurable time. `EDITOR` is now a literal.                                                                                              |
| `~/.fzf.zsh` loader                        | Unmanaged, generated by fzf's install script, hardcoded `/opt/homebrew/opt/fzf/shell/*`. Replaced by `eval "$(fzf --zsh)"` — verified byte-identical in content, differing only in ordering. Its PATH addition was redundant; `fzf-tmux` resolves via `/opt/homebrew/bin`.            |
| Linux Homebrew branch                      | `DOT_TARGET` was hardcoded `"macos"`, so the branch was unreachable. This rig is macOS-only.                                                                                                                                                                                          |
| `mysql-client` PATH block                  | Neither the directory nor the `mysql` binary exists.                                                                                                                                                                                                                                  |
| `~/bin` PATH entry                         | Directory does not exist; `~/.bin` is the real one.                                                                                                                                                                                                                                   |
| pyenv block                                | Already commented out, and `~/.pyenv` absent.                                                                                                                                                                                                                                         |
| Empty `.zprofile` — **superseded, see §3** | The *empty* placeholder was removed. Its stated rationale ("macOS `/etc/zprofile` handles login-shell `path_helper`") was **backwards**: `path_helper` is what breaks the order. `.zprofile` was re-created with real content in `4a77e3b` and is now load-bearing. Do not delete it. |
| zinit / zsh-defer / eval caches            | See §4. Determinism over milliseconds.                                                                                                                                                                                                                                                |
| tmux-resurrect / continuum                 | Session persistence is manual by choice.                                                                                                                                                                                                                                              |
| `dot_bin/search.sh` (`rgs`, `fds`)         | Both wrapped `tv` (television), which is not installed — the commands errored on every invocation. `fzf`, `fd`, `rg` and the `C-f` yazi widget already cover this ground.                                                                                                             |
| `alias azvms`                              | `az` not installed, and the alias was **unguarded** — a broken command waiting to be typed. `dovms` beside it is now `can_haz doctl`-guarded.                                                                                                                                         |
| `alias d=lazydocker`                       | `lazydocker` not installed. Guarded, so it failed silently — pure dead weight.                                                                                                                                                                                                        |
| `wt-dev` / `w` dev-build block             | Pointed at `~/DEV/rd/wt/main/bin/wt`, which no longer exists. The released `wt` is installed and wired separately.                                                                                                                                                                    |
| `dot_config/nushell/`                      | `nu` not installed, zero references in either repo — 8.5K of config for a shell that never runs.                                                                                                                                                                                      |
| `~/.fzf/`                                  | A 1.6M git clone left by fzf's manual install script (Jan 2024). Unreferenced; fzf comes from Homebrew.                                                                                                                                                                               |
| `@last_exit_code` wiring                   | Producers in zsh + bash precmd with **no consumer**. Commit `9b4f131` ("catppuccin status bar redesign") deleted the reader; the producers were left behind and both docs kept claiming a "status bar error dot" that did not exist. Restore recipe below.                            |
| `[[ -o no_global_rcs ]] && return`         | Not dead — **actively wrong**. Under `zsh -d` the option is set, the guard fired, and the rest of `.zshenv` never ran: no PATH, no XDG, no GOPATH. `-d` means "skip `/etc/z*` global rcs", not "skip the user's own config".                                                          |
| `CLAUDE_GIT_PASSPHRASE` *(private repo)*   | Exported from `private.zsh` with **zero consumers** in either repo or `~/.claude`. Unrelated to git signing — signing is SSH via 1Password `op-ssh-sign`. Value remains in 3 commits of private history; purge + rotate is a separate operator task.                                  |

To restore the exit-code indicator, **both halves are required**. Producer (zsh):

```zsh
_tmux_exit_code() { local ec=$?; [[ -n "$TMUX" ]] && tmux set-option -qw @last_exit_code "$ec"; }
add-zsh-hook precmd _tmux_exit_code
```

Consumer — the window-list fragment deleted by `9b4f131`, recoverable via `git show 9b4f131^`:

```tmux
#{?#{&&:#{@last_exit_code},#{!=:#{@last_exit_code},0}},#[fg=red],...}●
```

Never add one half without the other. That asymmetry is precisely how this became orphaned config plus two false doc claims that survived for months.

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
