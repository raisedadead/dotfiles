# Maintenance context

This file owns current structure, load order, and gotchas. [README.md](README.md) owns setup; [CLAUDE.md](CLAUDE.md) owns editing rules; [MAINTENANCE.md](MAINTENANCE.md) owns probes. Keep rationale here once. Read versions, revisions, models, and inventories from their source files or tools.

## Deploy loop

Edit target → validate → the agent captures → inspect Git diff → commit. The source is `~/.dotfiles`. Editor saves do not apply source files automatically; `chezmoi edit --apply <target>` is the explicit source-edit path. Settings: [.chezmoi.toml.tmpl](.chezmoi.toml.tmpl).

The `dev.mrugesh.chezmoi-autocapture` launch agent runs [`~/.bin/chezmoi-autocapture.sh`](exact_dot_bin/executable_chezmoi-autocapture.sh) every 300 seconds. The script captures only the targets that `chezmoi status` reports as modified. It therefore removes no source entry and adds no unmanaged sibling, which a bare `re-add` of an `exact_` directory does. It skips the run while a merge, rebase, cherry-pick or revert is in progress in the source. It scans each captured file with `gitleaks` and exits 1 on a hit. It never commits, so each capture arrives as an unstaged change. Its log is `~/.local/state/chezmoi-autocapture.log`. `install.sh` loads the agent; a manual reload needs `launchctl bootout gui/$UID/dev.mrugesh.chezmoi-autocapture` first, because `bootstrap` is not idempotent. Run `chezmoi add <target>` to manage a new file, and `chezmoi re-add <target>` to capture one target at once.

The agent overwrites an unapplied source change within 300 seconds. Apply before you edit a source file by hand, revert one with `git checkout --`, or stash in `~/.dotfiles`. Git cannot recover an uncommitted change that the agent overwrites.

`dot_claude/` is a git submodule of the private repo `raisedadead/dotfiles-private`, branch `dot_claude`; a capture of a `~/.claude` target lands there. Commit inside `dot_claude/` first, then commit the gitlink bump in `~/.dotfiles`. `.githooks/pre-commit` exits 1 while a submodule is dirty or ahead of the staged gitlink, and it prints the next command. `.githooks/pre-push` exits 1 when a submodule commit reached no remote, because a clone of the parent cannot then check that submodule out. `submodule.recurse` is `false`, because `true` makes `pull`, `checkout`, `switch` and `reset` overwrite the submodule working tree with the recorded gitlink and rewind newer work. `submodule.dot_claude.update` is `merge`, so an explicit `git submodule update` is a no-op while the branch is ahead. `push.recurseSubmodules` stays `on-demand`. Each private directory is one orphan branch named after it, mounted with `git submodule add -b <dir>`. A private branch root may hold only `.git*`-prefixed files; chezmoi skips those and deploys anything else under the target.

| Kind | Source | Maintenance |
| --- | --- | --- |
| Ordinary file, including plain encrypted file | `dot_`, `private_`, `encrypted_` entries | Edit target and `re-add`; `private_` controls target permissions, `encrypted_` controls encryption at rest |
| Template | `dot_config/glow/glow.yml.tmpl`, `dot_aws/encrypted_private_config.tmpl.age` | Edit source; `re-add` skips templates |
| Modify script | `modify_private_dot_claude.json` | Edit source; it merges into existing target state |
| External | [.chezmoiexternal.toml](.chezmoiexternal.toml) | Change the declared revision or checksum; `source-path` is not an editable source-file lookup for externals |
| Repository document or bootstrap | Root Markdown and `install.sh` | Edit source; excluded from deployment |

Before an apply, inspect `chezmoi status` and `chezmoi diff`. Column-one `M` means a target edit; `D` means a deleted target. Without a saved `entryState`, overwrite detection is incomplete. Do not delete that state to resolve drift.

`exact_dot_bin`, `dot_config/exact_zsh`, and `dot_config/exact_git` own their target directories exactly. Apply can remove extra entries there. Keep generated state elsewhere. Completion data lives in `~/.zfunc`, `~/.zcompdump`, and `$XDG_CACHE_HOME/zsh`; plugin checkouts live under `$XDG_DATA_HOME/zsh/plugins`.

**Exact-directory capture has a wider scope than its path suggests.** On the installed chezmoi implementation, `re-add` of an exact directory captures new children and removes source entries for deleted children. A child-file `re-add` also captures new siblings, but does not remove a deleted sibling. Inspect the directory before capture and the source diff afterward. Probe this again after chezmoi upgrades; implementation: [readdcmd.go](https://github.com/twpayne/chezmoi/blob/v2.72.1/internal/cmd/readdcmd.go).

Do not track authentication, sessions, databases, logs, caches, installed plugins, or skill symlinks; `.chezmoiignore` controls deployment, Git ignores do not. Outside exact directories, removing a source entry can leave an unmanaged target. Inspect and remove that orphan explicitly. `re-add` does not capture templates, modify targets, externals, or symlink entries.

[.chezmoiignore](.chezmoiignore) uses target paths relative to `$HOME`. A leading `/` is invalid. A bare `.claude` excludes that tree. Git ignores do not control deployment, and untracked source files can deploy. Root documentation and `AGENTS.md` are excluded from deployment.

Stage startup changes with an isolated destination and persistent-state file before a broad apply. A broken `.zshrc` affects new shells immediately. Do not use a staging apply as a substitute for inspecting live drift.

## Terminal stack

| Layer | Owner | Contract |
| --- | --- | --- |
| Desktop | `dot_config/aerospace/` | Desktop shortcuts are consumed before the terminal |
| Terminal | [Ghostty](dot_config/ghostty/config.ghostty) | Rendering, native selection, scrollback, selected key rewrites |
| Multiplexer | [tmux](dot_config/tmux/tmux.conf), [keybindings](dot_config/tmux/keybinds.conf) | Sessions, panes, popups, root `M-` bindings, editor arbitration |
| Shell | [zsh](dot_config/exact_zsh/dot_zshrc) | Emacs editing, completions, history, command execution |
| Editor | [Neovim](dot_config/nvim/) | LazyVim defaults plus local overrides |

A root tmux binding consumes its key before zsh or Neovim. Check `ghostty +list-keybinds`, `tmux list-keys -T root`, and live `bindkey` before assigning one. Ghostty Alt+Left/Right send `M-b`/`M-f`; an unbound tmux key can still be a shell motion.

`smart-splits.nvim` produces `@pane-is-vim`. tmux uses it to forward `M-H/J/K/L` to Neovim or select a pane. The same flag routes Ghostty's Ctrl+Shift+W/E/A/S rewrites: Neovim receives plain Ctrl+W/E/A/S; other panes receive `M-C-w/e/a/s`. Direct Neovim outside tmux has no such arbitration. Ctrl+Shift+W deletes to line start in zsh.

Ghostty's [Option+Shift encoding issue](https://github.com/ghostty-org/ghostty/issues/9406) is the reason tmux omits client `extkeys` and keeps legacy uppercase plus CSI-u bindings. `terminal-features` resets before appending, so reloads do not duplicate entries. Check the client features, not only `extended-keys`.

Ghostty shell-integration features add to defaults. Inspect `ghostty +show-config`; keep `path` enabled so its command remains reachable. Ctrl+Shift+H/J/K/L scroll Ghostty history, which differs from tmux copy-mode history. Mouse drag uses tmux selection; Shift+drag uses native terminal selection.

The shader chain is cursor warp followed by text glow. The default animation mode renders focused shader surfaces continuously. Compare equal-size static and scrolling surfaces before changing it; disabling animation also changes the cursor effect. [Ghostty documents the animation modes](https://ghostty.org/docs/config/reference#custom-shader-animation). CPU samples alone do not measure GPU or battery cost.

### zsh startup and PATH

| File | Responsibility |
| --- | --- |
| `~/.zshenv` | Set `ZDOTDIR` and explicitly source its `.zshenv`; zsh does not reread it after the directory changes |
| `.config/zsh/.zshenv` | Environment and `path.zsh` |
| `.config/zsh/.zprofile` | Reapply PATH after macOS `/etc/zprofile` runs `path_helper` |
| `.config/zsh/.zshrc` | Interactive setup and ordered integrations |
| `.config/zsh/plugins.zsh`, `plugins.lock` | Pinned plugin bootstrap and explicit updates |
| `.config/zsh/completions.zsh` | Completion cache and generated providers |
| `.config/zsh/fzf.zsh` | Picker behavior and theme |
| `.config/zsh/alias.zsh`, `private.zsh`, `~/.bin/functions.sh` | Aliases, 1Password shell integration, optional helpers |

[path.zsh](dot_config/exact_zsh/path.zsh) prepends in order; the last prepend wins. Its unique PATH places user commands and fnm's default alias before Homebrew. `.zprofile` restores that order after `path_helper`. [dot_bashrc](dot_bashrc) carries the fnm prepend too. GUI processes that read no shell startup file need their own PATH; unmanaged `/usr/local/bin` links are machine state.

Startup stays synchronous: options/keymaps → prompt → pinned plugin setup → fzf → unique fpath and compinit → fzf-tab → widget wrappers → tool integrations → aliases/functions → fnm. fzf-tab belongs after compinit and before highlighting/autosuggestions. Atuin loads after fzf and owns Ctrl+R. No deferred plugins, plugin manager, or cached init evaluations.

`plugins.lock` records repository and commit. Missing plugins clone at that commit. A changed lock synchronizes existing checkouts at next startup; tracked local edits cause an error. `zsh-plugin-update` explicitly fetches upstream HEADs, synchronizes them, and records the resulting pins. Capture the lock afterward. The pnpm completion helper is generated inside its checkout. Do not put checkout state in the exact zsh directory.

`fpath` is unique. The cache signature includes provider directories, their metadata, and entry names. Directory changes or cache age trigger compinit; `rebuild-completions` handles provider-content changes that leave the directory signature unchanged. `update-completions` generates gh, op, and wrangler providers through temporary files and then rebuilds. Run it after upgrading those tools.

Chezmoi keeps its packaged `_chezmoi` command/flag completion, with `completion.custom=false` for native path fallback. Its custom path candidates can fail to match a tilde prefix ([Cobra issue](https://github.com/spf13/cobra/issues/1577)). A scoped completion style includes dotfiles. Native fallback can offer unmanaged paths; `re-add` still decides what it can capture.

Ctrl+T replaces the shell argument at the cursor. An existing directory becomes the search root; a remaining fragment becomes the initial query. It preserves surrounding arguments, quotes inserted paths, supports multiple selections, and leaves the buffer intact on cancellation. It supports relative, absolute, and unquoted `~/` paths. It does not evaluate variables or command substitutions in the input. Inside a shell operator it does nothing.

Ctrl+T lists files and directories recursively, includes hidden paths, and respects Git ignores. `<C-g>` includes Git-ignored entries for that picker invocation; fixed exclusions such as `.git`, `node_modules`, and `.venv` still apply. Preview uses a directory tree, numbered text, or binary metadata. Alt+C uses the same default ignore policy.

Emacs mode is the default; Ctrl+Z enters/exits `vicmd`, and Ctrl+F opens `mdr`. Dot-prefixed forward-motion widgets move without accepting autosuggestions; Ctrl+E and Ctrl+Shift+E accept them deliberately. Keep `DIRENV_LOG_FORMAT` exported above the direnv hook.

OMP cache cleanup matches UUID session caches only. Do not include `init.*.zsh` or bare `omp.cache`: active prompts depend on those files. Keep the array slice `"${(@)_c[51,-1]}"`; omitting `(@)` joins paths and removes nothing.

### tmux and pickers

A tmux test server needs a unique explicit `-L` or `-S`, including in subprocesses; `-f` and `TMUX_TMPDIR` do not isolate the live server. Inspect parse output as well as exit status.

[theme.conf](dot_config/tmux/theme.conf) owns palette and menu options. Use IDs for menu targets and escape displayed names. Command-local menu colors are literal; global menu style options accept formats. Painted popup backgrounds are opaque even with Ghostty transparency.

Use tmux `-N` notes for binding descriptions. [keys](exact_dot_bin/executable_keys) reads tool reports at runtime. Popup titles are plain and centered; tab bars use headers and action hints use footers. Use vim key notation inside picker hints. State fzf options at each popup call: inherited `FZF_DEFAULT_OPTS` can change height or truncation. `--keep-right` also truncates headers/footers from the left; test the real popup width.

[Switcher](dot_config/tmux/scripts/executable_switcher.sh) combines sessions, projects, config roots, and zoxide. Files walks the pane's current directory without a depth or row cap. Grep reloads ripgrep for the current regular expression; an empty query produces no rows. Search respects ignore files and includes hidden paths. Search rows encode target paths separately from display text, so colons and separators do not change the editor target.

Switcher bookmarks live at `$XDG_STATE_HOME/switcher/bookmarks`, one absolute directory per line. Keep them unmanaged. `~/.config/switcher/projects.json` is optional; `baseFolders[].scope` has no display effect. Bookmark reloads retain the active tab. A tab or newline in a bookmark path is outside that store's format.

[reader.sh](dot_config/tmux/scripts/executable_reader.sh) and standalone [mdr](exact_dot_bin/executable_mdr) share action behavior through mdr subcommands but retain separate fzf bindings. Update both action sets together. `mdr --docs <directory>` is valid; `mdr docs` treats `docs` as a directory.

Reader rows are NUL-delimited, with the path after the first tab; sanitize only display text. Keep the Perl renderer for large walks. Scratch uses `--no-ignore`; ordinary views have explicit `.claude` handling. A positive ripgrep glob is an inclusion rule, so a Markdown-only glob would empty the general Files view. Off-repository walks have a depth-six cap; deeper files need a narrower starting directory.

Force color and pager options in previews: bat and glow behave differently off a TTY. Glow does not expand `~` in its style path, so its configuration is a template. An unreadable style path fails; mdr falls back to the built-in dark style. Keep the explicit temporary-file removal before `exec glow`; an EXIT trap does not run after exec.

Sessions are parked manually with `@parked`; their processes keep running. There is no automatic restore. The first window is named Main; later windows use the shared `@cmd_name` mapping. [input-lib.sh](dot_config/tmux/scripts/input-lib.sh) needs Homebrew Bash for namerefs.

Reload adds or overwrites tmux bindings/options; removed source lines do not clear old runtime state. Use explicit unbind/unset when removing one. A `run-shell` string expands formats before its child command; double `#` when the inner command needs the format. `M-\\` is unsuitable for a menu shortcut because ESC-backslash terminates DCS ([tmux issue](https://github.com/tmux/tmux/issues/4386)).

### Neovim

[lua/config](dot_config/nvim/lua/config/) holds LazyVim deltas; [lua/plugins](dot_config/nvim/lua/plugins/) holds plugin overrides. Check upstream defaults before adding one. Use `catppuccin-mocha`: bare `catppuccin` can resolve to Neovim's built-in colorscheme and ignore plugin transparency.

`chezmoi.nvim` does not watch source buffers automatically. Edit deployed targets and capture them, or explicitly request a source apply. The local whitespace autocmd trims selected code/config filetypes only. It preserves Markdown and plain text, respects global/buffer autoformat switches, and skips binary, special, nonmodifiable, and large buffers. Keep it separate from a conform catch-all formatter, which would suppress LSP fallback.

Plugin update checking is off. Run `:Lazy update`, then `chezmoi re-add ~/.config/nvim/lazy-lock.json`. `:Lazy sync` also removes plugins absent from the spec. Use `<leader>sg` or `<leader>/` for grep, `<leader>fg` for Git files, `<leader>sh` for help. Explorer comes from the Snacks explorer extra.

## Desktop and utilities

AeroSpace and Sketchybar share workspace names across `aerospace.toml`, `sketchybar/lua/items/spaces.lua`, and the bracket in `sketchybarrc`. Update those consumers together. Read layout keys and triggers from the AeroSpace source; do not duplicate their values here. Unmatched windows follow the floating catch-all rule.

GUI-launched rule scripts need absolute executable paths. AeroSpace layouts use `layout-run.lua` and `layout.lua`; `lockf` serializes changes. Resize weights use the visible screen frame and gaps. Keep scalar horizontal gaps in the TOML configuration.

Shell helpers use `_mrgsh_` internal names and `can_haz` for optional tools. `executable_` marks programs, not sourced files. `awake` stores PID/deadline/spec state; its process check verifies `caffeinate`, but cannot distinguish a reused PID belonging to another caffeinate process.

## Agent rig

| Source | Responsibility |
| --- | --- |
| [dot_claude/settings.json](dot_claude/settings.json) (private submodule) | Hook wiring, plugins, MCP declarations, statuslines, settings |
| [hooks/executable_hooks.py](dot_claude/hooks/executable_hooks.py) | Event dispatcher and runtime decisions |
| [hooks/hook_config.json](dot_claude/hooks/hook_config.json) | Rule and gate configuration |
| [validators.json](dot_claude/hooks/validators.json), [formatters.json](dot_claude/hooks/formatters.json) | Tool registries |
| [dot_claude/CLAUDE.md](dot_claude/CLAUDE.md), [rules](dot_claude/rules/) | Kernel and path-scoped instructions |
| [agents](dot_claude/agents/), [skills](dot_claude/skills/), [workflows](dot_claude/workflows/) | Delegation contracts and reusable work |
| [dot_cavemem/settings.json](dot_cavemem/settings.json) | Memory configuration; runtime database stays unmanaged |

Use source and runtime probes for model names, plugin revisions, tool inventories, and rule thresholds. A configured key is evidence of intent; the handler and its probe establish behavior.

SessionStart registers the main marker and runs the doctor. PreToolUse evaluates command/file rules and spawn contracts. PostToolUse formats, validates, queues project checks, and records mutations. SubagentStop records completed review agents. Stop handles failure suppression, review, length, claims, queued validators, and notification. SessionEnd cleans session state. Read the dispatcher for other events and error paths.

The review request belongs to the operator. Keep that wording in the kernel and gate message. A completed review-class agent satisfies the marker; a planned or crashed review does not. Workflow agents need the recognized reviewer type. Shell-driven edits are outside the file-tool mutation recorder, so the agent still owes the requested review.

### Hook gotchas

- Test with isolated `MARKERS_DIR` **and** `MAIN_SESSION_MARKER`. A fake young main-session marker can silence real-session review and notification behavior.
- Read configuration before fallback constants. An existing configuration key takes precedence; editing its fallback has no effect.
- Stop uses `stop_hook_active` to avoid a correction loop. Emit one JSON decision, then exit. A gate error must not discard the later validator drain accidentally.
- Project roots can disappear before queued validation runs. Handle `OSError`, including `FileNotFoundError`.
- Spawn contracts need `OUTPUT:` and `DONE:`; named agents also need `REPORT:`. The gate checks presence, not quality. Workflow-internal prompts need the same contract manually. Roster writes need `fcntl.flock`.
- Test new hook regexes with long adverse inputs. Nested quantifiers can stall the hook. Tool matchers match full names, not substrings.
- `git commit -F` is outside the command-string `-m` checks. Malformed hook input and several hook error paths return without denial. Inspect the handler before claiming enforcement.
- The claim checker rejects on exit 1; missing plugins, timeouts, and other errors pass. It checks claim form, not truth. Resolve its path through the installed-plugin registry.
- Stop length checks happen after the first reply is visible. Keep the kernel and output style concise as well.

RTK has two command writers: the dispatcher allowlist and native `rtk hook claude`. Keep one owner per command word. Before adding an allowlist word, `rtk hook check '<word> x'` must return `No rewrite`. Preserve argv in `rtk proxy`; re-parsing a quoted command string can change escapes and counts. Investigate entries in `~/.claude/markers/rtk-corruption.log`.

### Plugins, MCP, and memory

First-party plugin source is `~/DEV/rd/claude-code-plugins`. Resolve deployed files from `~/.claude/plugins/installed_plugins.json` and its `installPath`; cache directory names can be versions rather than SHAs. Plugin-registered hooks run outside the dispatcher; disable the plugin in `enabledPlugins` to stop those hooks. Inspect manifests and hook registrations before enabling one.

`settings.json.mcpServers` is canonical. [modify_private_dot_claude.json](modify_private_dot_claude.json) merges that key into `~/.claude.json`, preserving other state; failure paths pass the input through. Probe drift with `chezmoi diff ~/.claude.json` and connectivity with `claude mcp list`. Duplicate server names at multiple scopes can split OAuth state.

Cavemem keeps its database under `~/.cavemem`. Do not run `cavemem install` over the managed settings. After a fnm default change, use `chezmoi-claude-bootstrap.sh --only cavemem` to restore the embedder dependency and native modules. Do not rely on configured privacy globs without probing their consumer. If search raises `Maximum call stack size exceeded`, use timeline/observation tools. The capture configuration omits upstream's SessionStart context injection.

Keep native `autoMemoryEnabled` off for this managed rig. Native writes can create target drift. Pi runtime is `~/.pi/agent`; its source belongs to `~/DEV/rd/pi-kit`, outside this deployment.

### Statusline

[statusline.sh](dot_claude/statusline/executable_statusline.sh) supplies `ICON_*` variables to [theme.omp.yaml](dot_claude/statusline/theme.omp.yaml). Keep the YAML ASCII-clean to avoid PUA glyph loss in file tools. The subagent statusline is a separate jq renderer.

Effort reads `.effort.level`, then `CLAUDE_EFFORT`; the CLI's input override is not a reliable exported value. `session-alert.py` reads the transcript for unresolved downgrade/API alerts. Keep `switchModelsOnFlag: false` and probe runtime behavior; a source setting alone does not prove server behavior.

## Operator tools

`chezmoi-autocapture.sh` is the capture agent's program; see the deploy loop. `chezmoi-claude-doctor.sh` diagnoses configuration and drift. `chezmoi-claude-bootstrap.sh` installs runtime prerequisites. `chezmoi-claude-hooks-test.sh --all` runs the source test suites. `dotfiles-privatize.sh <dir> [--push]` moves a source directory into the private submodule repo as branch `<dir>` and adds the README row; without `--push` it prepares the branches and prints the remaining commands. Use `rig-change-review` for Claude rig changes and `code-review` for other source changes.

The workflow directory registers scripts through `meta.name`: inspect it for the current roster. Operator-only utilities without automated consumers are `cavemem-seed.ts`, `claude-flag-audit.sh`, `check_for_updates.sh`, and `tailscale-mgmt.sh` in `exact_dot_bin/`.
