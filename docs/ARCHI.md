# How this setup works

This guide explains ownership, load order, and constraints that matter when you change the setup. [README.md](../README.md) holds the install steps. [README.md](README.md) here holds the chezmoi commands. [MAINTENANCE.md](MAINTENANCE.md) holds the probes. [AGENTS.md](../AGENTS.md) is the entry point for every coding agent. Read versions, revisions, and inventories from the source files or the tools, not from here.

## Contents

- [Deployment and capture](#deployment-and-capture)
- [Private submodules](#private-submodules)
- [Terminal stack](#terminal-stack)
- [Desktop and utilities](#desktop-and-utilities)
- [Agent rigs](#agent-rigs)
- [Claude Code](#claude-code)
- [Codex](#codex)
- [Operator tools](#operator-tools)

## Deployment and capture

Edit the target. Validate it. Run `chezmoi status`, then `chezmoi re-add <target>`. Inspect the Git diff. Commit. Nothing captures a target on its own. Settings: [.chezmoi.toml.tmpl](../.chezmoi.toml.tmpl).

Read `chezmoi status` before a bare `chezmoi re-add`. A bare `re-add` captures every modified target, including an installer or runtime write. Capture one target at a time when the list holds a change you did not make. Revert the rest with `chezmoi apply <target>`.

| Kind                                       | Source                                                                       | Maintenance                                         |
| ------------------------------------------ | ---------------------------------------------------------------------------- | --------------------------------------------------- |
| File, plain or encrypted                   | `dot_`, `private_`, `encrypted_` entries                                     | Edit the target and `re-add`. `re-add` re-encrypts  |
| Template                                   | `dot_config/glow/glow.yml.tmpl`, `dot_aws/encrypted_private_config.tmpl.age` | Edit the source. `re-add` skips templates           |
| Modify script                              | `modify_private_dot_claude.json`                                             | Edit the source. It merges into the existing target |
| External                                   | [.chezmoiexternal.toml](../.chezmoiexternal.toml)                            | Change the pinned revision or checksum              |
| Repository document, `docs/`, `install.sh` | Root files                                                                   | Edit the source. Not deployed                       |

`re-add` does not capture templates, modify targets, externals, or symlink entries. Before an apply, read `chezmoi status` and `chezmoi diff`. Column one `M` is a target edit. Column one `D` is a deleted target. Do not delete the chezmoi state to resolve drift.

`exact_dot_bin`, `dot_config/exact_zsh`, and `dot_config/exact_git` own their target directories. Apply removes an entry there that the source does not hold. Keep generated state elsewhere. Completion data lives in `~/.zfunc`, `~/.zcompdump`, and `$XDG_CACHE_HOME/zsh`. Plugin checkouts live under `$XDG_DATA_HOME/zsh/plugins`.

A `re-add` of an exact directory captures new children and removes source entries for deleted children. Inside an exact directory, a `re-add` of one child file also captures new siblings; outside one it takes the named file only (`chezmoi-fixture-check.sh` check 6 asserts both). Inspect the directory before a capture and the source diff after it. Implementation: [readdcmd.go](https://github.com/twpayne/chezmoi/blob/v2.72.1/internal/cmd/readdcmd.go).

[.chezmoiignore](../.chezmoiignore) controls deployment. Git ignores do not. Its paths are relative to `$HOME`, without a leading `/`. An untracked source file deploys. Do not track authentication, trust records, sessions, databases, logs, caches, generated memories, installed plugins, or skill symlinks. Outside an exact directory, a removed source entry leaves the target in place. Remove that orphan yourself.

Stage a shell startup change with an isolated destination and state file before a broad apply. A broken `.zshrc` affects every new shell.

### Private submodules

`dot_claude/`, `dot_codex/`, and `dot_agents/` are git submodules of `raisedadead/dotfiles-private`, on branches with the same names. Each has an independent history. The following Claude example also describes the Codex capture and gitlink flow. A capture of a `~/.claude` target lands there. Commit inside `dot_claude/`. Its `.githooks/post-commit` then commits the gitlink bump in `~/.dotfiles` as `chore(dot_claude): bump to <sha>`. The hook exits 0 without a commit when there is no superproject, when the parent is mid-merge or mid-rebase, or when `HEAD` already records the gitlink. When the parent tip is a bump that no remote holds, the hook amends it. The bump takes the parent author and date. `status.submoduleSummary` lists a submodule commit the parent does not record yet.

Both repos run `gitleaks` in `.githooks/pre-commit` and exit 1 on a finding. The parent `.githooks/pre-push` resolves the gitlink of each commit in each pushed range. It exits 1 when that submodule commit is on no remote, or when it cannot check it. A clone of the parent cannot check out such a commit.

Git settings in `dot_gitconfig`: `submodule.recurse = false`, because `true` lets `pull`, `checkout`, `switch`, and `reset` rewind the submodule working tree. `submodule.<name>.update = merge` for each of the three, so `git submodule update` is a no-op while the branch is ahead. `push.recurseSubmodules = on-demand`.

Each private directory is one orphan branch with the directory name, mounted with `git submodule add -b <dir>`. Private branch repository metadata uses `.git*`-prefixed files, which chezmoi skips. Deployable configuration also lives at the branch root. Codex owner documents under `docs/` are excluded explicitly. `dotfiles-privatize.sh` seeds `pre-commit` and `post-commit` from the parent `.githooks/` into a new private branch.

## Terminal stack

| Layer       | Source                                                                                | Owns                                                            |
| ----------- | ------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| Desktop     | `dot_config/aerospace/`                                                               | Desktop shortcuts, read before the terminal                     |
| Terminal    | [Ghostty](../dot_config/ghostty/config.ghostty)                                       | Rendering, native selection, scrollback, key rewrites           |
| Multiplexer | [tmux](../dot_config/tmux/tmux.conf), [keybindings](../dot_config/tmux/keybinds.conf) | Sessions, panes, popups, root `M-` bindings, editor arbitration |
| Shell       | [zsh](../dot_config/exact_zsh/dot_zshrc)                                              | Emacs editing, completions, history                             |
| Editor      | [Neovim](../dot_config/nvim/)                                                         | LazyVim defaults plus local overrides                           |

A root tmux binding takes its key before zsh or Neovim. Before you assign a key, check `ghostty +list-keybinds`, `tmux list-keys -T root`, and `bindkey`. Ghostty Alt+Left/Right send `M-b`/`M-f`.

`smart-splits.nvim` sets `@pane-is-vim`. tmux uses it to forward `M-H/J/K/L` to Neovim or to select a pane. The same flag routes Ghostty's Ctrl+Shift+W/E/A/S rewrites: Neovim receives plain Ctrl+W/E/A/S, other panes receive `M-C-w/e/a/s`. Ctrl+Shift+W deletes to line start in zsh.

tmux omits client `extkeys` and keeps legacy uppercase plus CSI-u bindings because of Ghostty's [Option+Shift encoding issue](https://github.com/ghostty-org/ghostty/issues/9406). `terminal-features` resets before it appends, so a reload does not duplicate entries. Check the client features, not only `extended-keys`.

Ghostty shell-integration features add to the defaults. Keep `path` enabled. Ctrl+Shift+H/J/K/L scroll Ghostty history, not tmux copy mode. Mouse drag selects in tmux. Shift+drag selects in the terminal.

The shader chain is cursor warp, then text glow. The default animation mode renders focused shader surfaces continuously. A change to the animation mode also changes the cursor effect ([Ghostty reference](https://ghostty.org/docs/config/reference#custom-shader-animation)). CPU samples alone do not measure GPU or battery cost.

### zsh startup and PATH

| File                                                          | Owns                                                                                         |
| ------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| `~/.zshenv`                                                   | Sets `ZDOTDIR` and sources its `.zshenv`. zsh does not reread it after the directory changes |
| `.config/zsh/.zshenv`                                         | Environment and `path.zsh`                                                                   |
| `.config/zsh/.zprofile`                                       | Reapplies PATH after macOS `path_helper`                                                     |
| `.config/zsh/.zshrc`                                          | Interactive setup, in order                                                                  |
| `.config/zsh/plugins.zsh`, `plugins.lock`                     | Pinned plugins and explicit updates                                                          |
| `.config/zsh/completions.zsh`                                 | Completion cache and generated providers                                                     |
| `.config/zsh/fzf.zsh`                                         | Picker behavior and theme                                                                    |
| `.config/zsh/alias.zsh`, `private.zsh`, `~/.bin/functions.sh` | Aliases, 1Password shell integration, helpers                                                |

[path.zsh](../dot_config/exact_zsh/path.zsh) prepends in order. The last prepend wins. User commands and the fnm default come before Homebrew. `.zprofile` restores that order after `path_helper`. [dot_bashrc](../dot_bashrc) carries the fnm prepend too. A GUI process reads no shell startup file and needs its own PATH.

Startup order: options and keymaps, prompt, pinned plugins, fzf, unique fpath and compinit, fzf-tab, widget wrappers, tool integrations, aliases and functions, fnm. fzf-tab loads after compinit and before highlighting and autosuggestions. Atuin loads after fzf and owns Ctrl+R. There is no deferred loading and no plugin manager.

`plugins.lock` records repository and commit. A missing plugin clones at that commit. A changed lock synchronizes an existing checkout at the next startup. A local edit in a checkout causes an error. `zsh-plugin-update` fetches the upstream heads and records the new pins. Capture the lock after it. Keep checkout state out of the exact zsh directory.

The completion cache signature includes provider directories, metadata, and entry names. A directory change or cache age triggers compinit. `rebuild-completions` handles a provider content change. `update-completions` regenerates the gh, op, and wrangler providers. Run it after you upgrade those tools.

chezmoi keeps its packaged `_chezmoi` completion with `completion.custom = false`. Its custom path candidates can fail on a tilde prefix ([Cobra issue](https://github.com/spf13/cobra/issues/1577)). A scoped completion style includes dotfiles. The native fallback can offer an unmanaged path.

Ctrl+T replaces the shell argument at the cursor. An existing directory becomes the search root. A remaining fragment becomes the query. It keeps the other arguments, quotes the inserted path, and leaves the buffer intact on cancel. It does not evaluate variables or command substitutions. It lists files and directories recursively, includes hidden paths, and respects Git ignores. `<C-g>` includes Git-ignored entries for that call. Alt+C uses the same ignore policy.

Emacs mode is the default. Ctrl+Z toggles `vicmd`. Ctrl+F opens `mdr`. Dot-prefixed forward-motion widgets move without accepting an autosuggestion. Ctrl+E and Ctrl+Shift+E accept one. Keep `DIRENV_LOG_FORMAT` exported above the direnv hook.

OMP cache cleanup matches UUID session caches only. Do not include `init.*.zsh` or bare `omp.cache`. Keep the array slice `"${(@)_c[51,-1]}"`. Without `(@)` the slice joins the paths and removes nothing.

### tmux and pickers

A tmux test server needs a unique `-L` or `-S` on every command, including subprocesses. `-f` and `TMUX_TMPDIR` do not isolate the live server. Read the parse output as well as the exit status.

[theme.conf](../dot_config/tmux/theme.conf) owns the palette and the menu options. Use IDs for menu targets. Escape displayed names. Command-local menu colors are literal. Global menu style options accept formats. A painted popup background is opaque, also with Ghostty transparency.

Use tmux `-N` notes for binding descriptions. [keys](../exact_dot_bin/executable_keys) reads tool reports at runtime. State the fzf options at each popup call, because an inherited `FZF_DEFAULT_OPTS` can change height or truncation. `--keep-right` also truncates headers and footers from the left. Test the real popup width.

[Switcher](../dot_config/tmux/scripts/executable_switcher.sh) combines sessions, projects, config roots, and zoxide. Files walks the pane directory without a depth or row cap. Grep reloads ripgrep for the current expression. An empty query produces no rows. Rows carry the target path separately from the display text. Bookmarks live at `$XDG_STATE_HOME/switcher/bookmarks`, one absolute directory per line, unmanaged. `~/.config/switcher/projects.json` is optional.

[reader.sh](../dot_config/tmux/scripts/executable_reader.sh) and [mdr](../exact_dot_bin/executable_mdr) share actions through mdr subcommands but keep separate fzf bindings. Update both together. Rows are NUL-delimited with the path after the first tab. Sanitize only the display text. A positive ripgrep glob is an inclusion rule. Off-repository walks stop at depth six.

Force color and pager options in previews. bat and glow behave differently off a TTY. Glow does not expand `~` in its style path, so its configuration is a template. Keep the temporary-file removal before `exec glow`. An EXIT trap does not run after exec.

Sessions are parked by hand with `@parked`. There is no automatic restore. The first window is `Main`. Later windows use the shared `@cmd_name` mapping. [input-lib.sh](../dot_config/tmux/scripts/input-lib.sh) needs Homebrew Bash for namerefs.

A tmux reload adds or overwrites bindings and options. A removed source line does not clear runtime state. Unbind or unset explicitly. A `run-shell` string expands formats before the child command. Double `#` when the inner command needs the format. `M-\\` cannot be a menu shortcut, because ESC-backslash ends a DCS ([tmux issue](https://github.com/tmux/tmux/issues/4386)).

### Neovim

[lua/config](../dot_config/nvim/lua/config/) holds LazyVim deltas. [lua/plugins](../dot_config/nvim/lua/plugins/) holds plugin overrides. Check the upstream default before you add one. Use `catppuccin-mocha`. Bare `catppuccin` can resolve to the built-in colorscheme.

`chezmoi.nvim` does not watch source buffers. The whitespace autocmd trims selected code and config filetypes only. It keeps Markdown and plain text, and it skips binary, special, nonmodifiable, and large buffers. Keep it separate from a conform catch-all formatter, which suppresses the LSP fallback.

Plugin update checks are off. Run `:Lazy update`, then `chezmoi re-add ~/.config/nvim/lazy-lock.json`. `:Lazy sync` also removes plugins absent from the spec.

## Desktop and utilities

AeroSpace and Sketchybar share workspace names across `aerospace.toml`, `sketchybar/lua/items/spaces.lua`, and the bracket in `sketchybarrc`. Update the three together. Read layout keys and triggers from the AeroSpace source. An unmatched window follows the floating catch-all rule. A GUI-launched rule script needs absolute executable paths. `lockf` serializes layout changes. Keep scalar horizontal gaps in the TOML.

Shell helpers use `_mrgsh_` internal names and `can_haz` for optional tools. `executable_` marks a program, not a sourced file. `awake` stores PID, deadline, and spec state. Its process check cannot tell a reused PID from another `caffeinate`.

## Agent rigs

Three coding agents run on this machine. Each owns its own global kernel and its own runtime. This repository is the source of truth for what they share: where a rig deploys, what stays unmanaged, and how a skill reaches each agent.

| Rig           | Source        | Target         | Kernel      | Rig reference                 | Checks    |
| ------------- | ------------- | -------------- | ----------- | ----------------------------- | --------- |
| Claude Code   | `dot_claude/` | `~/.claude/`   | `CLAUDE.md` | [Claude Code](#claude-code)   | M1 to M16 |
| Codex         | `dot_codex/`  | `~/.codex/`    | `AGENTS.md` | [RIG.md](../dot_codex/RIG.md) | C1 to C4  |
| Pi            | Unmanaged     | `~/.pi/agent/` | `AGENTS.md` | `~/DEV/rd/pi-kit`             | None here |
| Shared skills | `dot_agents/` | `~/.agents/`   | None        | [Skills](#skills)             | S1, S2    |

Pi stays outside chezmoi by the operator's decision. This is intentional, not a gap to fix.

### The rig contract

A managed rig is a `dot_<agent>/` submodule that deploys to `~/.<agent>/`. [Private submodules](#private-submodules) holds the branch layout and the hooks. [Deployment and capture](#deployment-and-capture) holds the capture loop and the state that stays unmanaged. Three conditions belong to a rig alone:

- Do not make the target an exact directory. [.chezmoiignore](../.chezmoiignore) keeps unmanaged paths out, but an untracked source file still deploys. A rig that needs a strict boundary uses an allow list. Codex is the one rig that does.
- [MAINTENANCE.md](MAINTENANCE.md) holds a check row for the rig.
- The rig's own kernel names this document, which links [AGENTS.md](../AGENTS.md) and the rest. One pointer is enough.

To add a rig: run `dotfiles-privatize.sh <dir>`, add the rig's entries to [.chezmoiignore](../.chezmoiignore), add a row to the table above, and add the check row.

### Project instructions

Codex and Pi read `AGENTS.md` in a project. Claude Code reads `CLAUDE.md` and does not read `AGENTS.md`, so `CLAUDE.md` is a symlink that holds `AGENTS.md`. This repository uses that layout. The `cmd-agents-md` skill converts another repository. A global kernel is not a project file.

### Skills

| Kind        | Home                                                                 | Reaches                                                                                                                                                 |
| ----------- | -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Personal    | `dot_claude/skills/<name>/` or `dot_codex/skills/<name>/`            | That agent alone                                                                                                                                        |
| Common      | `dot_agents/skills/<name>/`                                          | Pi reads `~/.agents/skills/` directly. Claude needs a `symlink_<name>` entry. Codex: read the note below                                                |
| Third-party | `npx skills add <repo> --skill <name> -g -a claude-code -a codex -y` | An unmanaged copy under `~/.agents/skills/` and an unmanaged link under `~/.claude/skills/`. One line in `docs/skills.tsv`, which lists them for replay |
| Plugin      | Its plugin                                                           | Never linked                                                                                                                                            |

Install a third-party skill with the command above, never by hand. Run `npx skills add <repo> -l` first to read the skill names. Capture one skill directory at a time: a whole-directory add takes the links and the copies with it.

Claude Code frontmatter: `disallowed-tools` removes a tool, and `allowed-tools` is advisory and does not (anthropics/claude-code#37683). A `cmd-*` skill sets `disable-model-invocation: false`. Keep the trigger phrases disjoint across skills. Write a path with forward slashes, never with a backslash. The `whetstone` plugin's `skill-smith` lints the rest.

UNVERIFIED: that Codex loads a skill from `~/.agents/skills` at run time. The Codex binary names that path. `~/.codex/skills/` holds no link to it.

Pi's doctor governs `~/.agents/skills/`. `~/.pi/agent/manifest.json` holds two lists for it. `externalSkills` names the third-party skills that must be present, and the `npx skills` lock must own each one. `managedSharedSkills` names the chezmoi-managed common skills that are allowed to be present. A name in the directory that neither list holds fails the `skills.external` check. Add each new common skill to `managedSharedSkills`, or ask the Pi rig to, or that check fails.

## Claude Code

| Source                                                                                                         | Owns                                                          |
| -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| [dot_claude/settings.json](../dot_claude/settings.json)                                                        | Hook wiring, plugins, MCP declarations, statuslines, settings |
| [hooks/executable_hooks.py](../dot_claude/hooks/executable_hooks.py)                                           | Event dispatcher and runtime decisions                        |
| [hooks/hook_config.json](../dot_claude/hooks/hook_config.json)                                                 | Rule and gate configuration                                   |
| [validators.json](../dot_claude/hooks/validators.json), [formatters.json](../dot_claude/hooks/formatters.json) | Tool registries                                               |
| [dot_claude/CLAUDE.md](../dot_claude/CLAUDE.md), [rules](../dot_claude/rules/)                                 | Kernel and path-scoped instructions                           |
| [agents](../dot_claude/agents/), [skills](../dot_claude/skills/), [workflows](../dot_claude/workflows/)        | Delegation contracts and reusable work                        |
| [dot_cavemem/settings.json](../dot_cavemem/settings.json)                                                      | Memory configuration. The database stays unmanaged            |
| [rtk config.toml](../Library/private_Application%20Support/private_rtk/config.toml)                            | RTK filters and hook exclusions; `git` is excluded            |

Probe the source and the runtime for model names, plugin revisions, tool inventories, and rule thresholds. A configured key shows intent. The handler and its probe show behavior.

[Skills](#skills) holds the four kinds and the shared store. A common skill reaches Claude through a `symlink_<name>` entry in `dot_claude/skills/` with the content `../../.agents/skills/<name>`. Doctor lint 5e checks the links and the source entries.

SessionStart registers the main marker and sets the session title. The doctor runs beside it as an `asyncRewake` hook at startup and wakes Claude with the issue lines when it finds any. TaskCreated denies a task name outside the `<GROUP><N> <title>` form. PreToolUse evaluates command and file rules and spawn contracts. PostToolUse formats, validates, queues project checks, and records mutations. SubagentStop clears the mutation ledger when a review agent completes. Stop handles failure suppression, review, claims, queued validators, and notification; a continued Stop skips the gates and the sound but still drains the validator queue. SessionEnd cleans session state. Read the dispatcher for the other events and the error paths.

The review request belongs to the operator. Keep that wording in the kernel and in the gate message. A completed review-class agent clears the ledger of mutated files, so a later edit gates again within the one-block-per-session cap. A planned or crashed review clears nothing. A workflow agent needs the recognized reviewer type. A shell-driven edit is outside the mutation recorder, so the agent still owes the review.

### Hook gotchas

- Test with an isolated `MARKERS_DIR` and `MAIN_SESSION_MARKER`. A fake young main-session marker silences review and notification behavior.
- Read the configuration before the fallback constants. An existing key wins. An edit to its fallback has no effect.
- Stop uses `stop_hook_active` against a correction loop. Emit one JSON decision, then exit. A gate error must not discard the validator drain.
- A project root can disappear before a queued validation runs. Handle `OSError`, including `FileNotFoundError`.
- A spawn contract needs `OUTPUT:` and `DONE:`. A named agent also needs `REPORT:`. The gate checks presence, not quality. Roster writes need `fcntl.flock`.
- Test a new hook regex with long adverse input. A nested quantifier can stall the hook. A tool matcher matches the full name, not a substring.
- `git commit -F` is outside the `-m` command-string checks. Malformed hook input and several error paths return without a denial. Inspect the handler before you claim enforcement.
- The claim checker rejects on exit 1. A missing plugin, a timeout, or another error passes. It checks claim form, not truth. Resolve its path through the installed-plugin registry.

Native `rtk hook claude` is the only RTK command writer. Keep argv in `rtk proxy`. `git` is excluded from the rewrite because the worktree isolation check refuses a rewritten git command (rtk-ai/rtk#3864).

### Plugins, MCP, and memory

First-party plugin source is `~/DEV/rd/claude-code-plugins`. Resolve a deployed file from `installPath` in `~/.claude/plugins/installed_plugins.json`. A cache directory name can be a version, not a SHA. A plugin-registered hook runs outside the dispatcher. Disable the plugin in `enabledPlugins` to stop it. Read the manifest and the hook registrations before you enable one.

`settings.json.mcpServers` is canonical. [modify_private_dot_claude.json](../modify_private_dot_claude.json) merges that key into `~/.claude.json` and keeps the other state. Probe drift with `chezmoi-claude-doctor.sh` check 4, which compares the `mcpServers` key alone. Do not use `chezmoi diff ~/.claude.json`: Claude Code writes other keys at run time, and a whole-file diff reports a false drift. Probe connectivity with `claude mcp list`. A duplicate server name at two scopes can split OAuth state.

Cavemem keeps its database under `~/.cavemem`. Do not run `cavemem install` over the managed settings. After an fnm default change, run `chezmoi-claude-bootstrap.sh --only cavemem`. If search raises `Maximum call stack size exceeded`, use the timeline and observation tools. Keep native `autoMemoryEnabled` off. A native write creates target drift.

### Statusline

[statusline.sh](../dot_claude/statusline/executable_statusline.sh) supplies `ICON_*` variables to [theme.omp.yaml](../dot_claude/statusline/theme.omp.yaml). Keep the YAML ASCII-clean. File tools lose PUA glyphs. The subagent statusline is a separate jq renderer. Effort reads `.effort.level`, then `CLAUDE_EFFORT`. `session-alert.py` reads the transcript for unresolved downgrade and API alerts. Keep `switchModelsOnFlag: false`. A source setting alone does not prove server behavior.

## Codex

`dot_codex/` owns the global instructions, code-style guide, rig reference, native command rules, hook registration, and Python hook source and tests. Read [RIG.md](../dot_codex/RIG.md) for behavior and limits. The hook uses Homebrew Python 3.11 or later. It does not load Claude files or require Claude plugins.

Git and chezmoi use explicit file lists for this directory. Keep `config.toml`, authentication, trust records, sessions, databases, logs, generated memories, and plugin caches unmanaged. Do not make `.codex` an exact directory. New managed files need an explicit addition to both lists. `.chezmoiignore` allows `skills/` and keeps Codex's own `.system/` tree out.

The private [owner plan](../dot_codex/docs/PLAN.md) and its archive preserve audit evidence and deferred decisions. They are source-only documents. A passing hook suite does not prove live interception. Review new hook definitions with `/hooks`, restart the client, and use disposable fixtures for live checks.

## Operator tools

| Tool                                   | Purpose                                                                                                           |
| -------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `chezmoi-claude-doctor.sh`             | Diagnoses configuration and drift                                                                                 |
| `chezmoi-claude-bootstrap.sh`          | Installs runtime prerequisites. `--check`, `--only`, `--skip`                                                     |
| `chezmoi-claude-hooks-test.sh --all`   | Runs the source test suites                                                                                       |
| `chezmoi-fixture-check.sh`             | Runs the C4 deployment fixture checks                                                                             |
| `dotfiles-privatize.sh <dir> [--push]` | Moves a source directory to the private repo as branch `<dir>`. Without `--push` it prints the remaining commands |
| `rig-change-review`, `lens-review`     | Review a rig change, or any other source change                                                                   |

The workflow directory registers scripts through `meta.name`. Operator-only utilities without an automated consumer: `cavemem-seed.ts`, `claude-flag-audit.sh`, `tailscale-mgmt.sh`. `tailscale-mgmt.sh` reads `TAILSCALE_OP_ITEM` from `~/.config/tailscale-mgmt.env`, an encrypted entry.
