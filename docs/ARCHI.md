# How this setup works

This guide explains ownership, load order, and constraints that matter when you change the setup. [README.md](README.md) here holds the install steps and the chezmoi commands. [MAINTENANCE.md](MAINTENANCE.md) holds the probes. [AGENTS.md](../AGENTS.md) is the entry point for every coding agent. Read versions, revisions, and inventories from the source files or the tools, not from here.

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

| Kind                                       | Source                                                                                                     | Maintenance                                         |
| ------------------------------------------ | ---------------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| File, plain or encrypted                   | `dot_`, `private_`, `encrypted_` entries                                                                   | Edit the target and `re-add`. `re-add` re-encrypts  |
| Template                                   | `dot_config/glow/glow.yml.tmpl`, `dot_aws/encrypted_private_config.tmpl.age`, `dot_pi/agent/mcp.json.tmpl` | Edit the source. `re-add` skips templates           |
| Modify script                              | `modify_private_dot_claude.json`, `dot_pi/agent/modify_settings.json`                                      | Edit the source. It merges into the existing target |
| External                                   | [.chezmoiexternal.toml](../.chezmoiexternal.toml)                                                          | Change the pinned revision or checksum              |
| Repository document, `docs/`, `install.sh` | Root files                                                                                                 | Edit the source. Not deployed                       |

`re-add` does not capture templates, modify targets, externals, or symlink entries. Before an apply, read `chezmoi status` and `chezmoi diff`. Column one `M` is a target edit. Column one `D` is a deleted target. Do not delete the chezmoi state to resolve drift.

`exact_dot_bin`, `dot_config/exact_zsh`, and `dot_config/exact_git` own their target directories. Apply removes an entry there that the source does not hold. Keep generated state elsewhere. Completion data lives in `~/.zfunc`, `~/.zcompdump`, and `$XDG_CACHE_HOME/zsh`. Plugin checkouts live under `$XDG_DATA_HOME/zsh/plugins`.

A `re-add` of an exact directory captures new children and removes source entries for deleted children. Inside an exact directory, a `re-add` of one child file also captures new siblings; outside one it takes the named file only (`chezmoi-fixture-check.sh` check 6 asserts both). Inspect the directory before a capture and the source diff after it. Implementation: [readdcmd.go](https://github.com/twpayne/chezmoi/blob/v2.72.1/internal/cmd/readdcmd.go).

[.chezmoiignore](../.chezmoiignore) controls deployment. Git ignores do not. Its paths are relative to `$HOME`, without a leading `/`. An untracked source file deploys. Do not track authentication, trust records, sessions, databases, logs, caches, generated memories, installed plugins, or skill symlinks. Outside an exact directory, a removed source entry leaves the target in place. Remove that orphan yourself.

Stage a shell startup change with an isolated destination and state file before a broad apply. A broken `.zshrc` affects every new shell.

### Private submodules

`dot_claude/`, `dot_codex/`, `dot_agents/`, and `dot_pi/` are git submodules of `raisedadead/dotfiles-private`, on branches with the same names. Each has an independent history. The following Claude example also describes the Codex capture and gitlink flow. A capture of a `~/.claude` target lands there. Commit inside `dot_claude/`. Its `.githooks/post-commit` then commits the gitlink bump in `~/.dotfiles` as `chore(dot_claude): bump to <sha>`. The hook exits 0 without a commit when there is no superproject, when the parent is mid-merge or mid-rebase, or when `HEAD` already records the gitlink. When the parent tip is a bump that no remote holds, the hook amends it. The bump takes the parent author and date. `status.submoduleSummary` lists a submodule commit the parent does not record yet.

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

`~/.zshenv` sets `ZDOTDIR` and sources `.config/zsh/.zshenv`. zsh does not reread `~/.zshenv` after the directory changes. `.zprofile` reapplies PATH after macOS `path_helper`.

[path.zsh](../dot_config/exact_zsh/path.zsh) prepends in order, so the last prepend wins. User commands and the fnm default come before Homebrew. [dot_bashrc](../dot_bashrc) carries the fnm prepend too. Keep the two in sync. A GUI process reads no shell startup file and needs its own PATH.

Keep the `.zshrc` order. fzf-tab loads after compinit and before highlighting and autosuggestions. Atuin loads after fzf and owns Ctrl+R.

`plugins.lock` records repository and commit. A missing plugin clones at that commit. A changed lock synchronizes an existing checkout at the next startup. A local edit in a checkout causes an error. `zsh-plugin-update` fetches the upstream heads and records the new pins. Capture the lock after it. Keep checkout state out of the exact zsh directory.

The completion cache signature includes provider directories, metadata, and entry names. A directory change or cache age triggers compinit. `rebuild-completions` handles a provider content change. `update-completions` regenerates the gh, op, and wrangler providers. Run it after you upgrade those tools.

chezmoi keeps its packaged `_chezmoi` completion with `completion.custom = false`. Its custom path candidates can fail on a tilde prefix ([Cobra issue](https://github.com/spf13/cobra/issues/1577)). A scoped completion style includes dotfiles. The native fallback can offer an unmanaged path.

Ctrl+T replaces the shell argument at the cursor. An existing directory becomes the search root, and the rest becomes the query. It does not evaluate variables or command substitutions. It respects Git ignores. `<C-g>` includes the ignored entries for that call.

`.zshrc` and `.bashrc` load the worktrunk wrapper with `wt config shell init`. Do not run `wt config shell install`, because it writes the deployed files. An agent shell does not load the wrapper, so `wt switch` cannot change its directory there. Move a Claude session with `EnterWorktree`.

Keep `DIRENV_LOG_FORMAT` exported above the direnv hook.

OMP cache cleanup matches UUID session caches only. Do not include `init.*.zsh` or bare `omp.cache`. Keep the array slice `"${(@)_c[51,-1]}"`. Without `(@)` the slice joins the paths and removes nothing.

### tmux and pickers

A tmux test server needs a unique `-L` or `-S` on every command, including subprocesses. `-f` and `TMUX_TMPDIR` do not isolate the live server. Read the parse output as well as the exit status.

[theme.conf](../dot_config/tmux/theme.conf) owns the palette and the menu options. Use IDs for menu targets. Escape displayed names. Command-local menu colors are literal. Global menu style options accept formats. A painted popup background is opaque, also with Ghostty transparency.

Use tmux `-N` notes for binding descriptions. [keys](../exact_dot_bin/executable_keys) reads tool reports at runtime. State the fzf options at each popup call, because an inherited `FZF_DEFAULT_OPTS` can change height or truncation. `--keep-right` also truncates headers and footers from the left. Test the real popup width.

[Switcher](../dot_config/tmux/scripts/executable_switcher.sh) rows carry the target path apart from the display text. Its bookmarks live unmanaged at `$XDG_STATE_HOME/switcher/bookmarks`, one absolute directory per line.

[reader.sh](../dot_config/tmux/scripts/executable_reader.sh) and [mdr](../exact_dot_bin/executable_mdr) share actions through mdr subcommands but keep separate fzf bindings. Update both together. Rows are NUL-delimited with the path after the first tab. Sanitize only the display text. A positive ripgrep glob is an inclusion rule. Off-repository walks stop at depth six.

Force color and pager options in previews. bat and glow behave differently off a TTY. Glow does not expand `~` in its style path, so its configuration is a template. Keep the temporary-file removal before `exec glow`. An EXIT trap does not run after exec.

[input-lib.sh](../dot_config/tmux/scripts/input-lib.sh) needs Homebrew Bash for namerefs.

A tmux reload adds or overwrites bindings and options. A removed source line does not clear runtime state. Unbind or unset explicitly. A `run-shell` string expands formats before the child command. Double `#` when the inner command needs the format. `M-\\` cannot be a menu shortcut, because ESC-backslash ends a DCS ([tmux issue](https://github.com/tmux/tmux/issues/4386)).

`run-shell` puts the pane in view mode when the child writes to stdout, or when the child exits non-zero. Stderr alone is safe. That pane then ignores keys until `q`, which reads as a frozen session. Each script binding therefore calls [run.sh](../dot_config/tmux/scripts/executable_run.sh), which sends the child output to `$XDG_STATE_HOME/tmux/<name>.log`, shows a message on a non-zero exit, and always exits 0 with empty stdout. Do not use `|| true`: it corrects the exit code and not the stdout.

Add `-b` only when the child opens a menu or a popup, because a blocking `run-shell` holds the client command queue until the child stops. Do not add `-b` elsewhere. It also removes the serialization, and repeated presses of a cycling key then race: three fast presses of `M-Tab` moved one session, not three. Quote each format that becomes a shell word with `#{q:...}`. A plain `'#{pane_current_path}'` runs arbitrary commands from a directory name that contains an apostrophe.

### Neovim

[lua/config](../dot_config/nvim/lua/config/) holds LazyVim deltas. [lua/plugins](../dot_config/nvim/lua/plugins/) holds plugin overrides. Check the upstream default before you add one. Use `catppuccin-mocha`. Bare `catppuccin` can resolve to the built-in colorscheme.

`chezmoi.nvim` does not watch source buffers. The whitespace autocmd trims selected code and config filetypes only. It keeps Markdown and plain text, and it skips binary, special, nonmodifiable, and large buffers. Keep it separate from a conform catch-all formatter, which suppresses the LSP fallback.

Plugin update checks are off. Run `:Lazy update`, then `chezmoi re-add ~/.config/nvim/lazy-lock.json`. `:Lazy sync` also removes plugins absent from the spec.

## Desktop and utilities

AeroSpace and Sketchybar share workspace names across `aerospace.toml`, `sketchybar/lua/items/spaces.lua`, and the bracket in `sketchybarrc`. Update the three together. Read layout keys and triggers from the AeroSpace source. An unmatched window follows the floating catch-all rule. A GUI-launched rule script needs absolute executable paths. `ctrl-alt-w` runs `aeroplace layout`, which serializes layout changes with `lockf`. Keep `outer.bottom` scalar in the TOML, because `aeroplace` reads it with a line match.

Set AeroSpace `outer.bottom` to the bar height plus its measured bottom inset plus the window gap: `30 + 6 + 8 = 44`. `y_offset = 3` raises the bar 6 pt. AeroSpace already excludes the native menu bar from its work area.

Keep `background.height` and `corner_radius` the same in `sketchybarrc`, `lua/items/front_app.lua`, and `lua/items/widgets.lua`. After a height or offset change, run `sketchybar --query bar` and check the screen geometry before you change the AeroSpace bottom gap ([SketchyBar properties](https://felixkratz.github.io/SketchyBar/config/bar)).

Shell helpers use `_mrgsh_` internal names and `can_haz` for optional tools. `executable_` marks a program, not a sourced file. `awake` stores PID, deadline, and spec state. Its process check cannot tell a reused PID from another `caffeinate`.

## Agent rigs

Three coding agents run on this machine. Each owns its own global kernel and its own runtime. This repository is the source of truth for what they share: where a rig deploys, what stays unmanaged, and how a skill reaches each agent.

| Rig           | Source        | Target       | Kernel      | System design                  | Checks    |
| ------------- | ------------- | ------------ | ----------- | ------------------------------ | --------- |
| Claude Code   | `dot_claude/` | `~/.claude/` | `CLAUDE.md` | [RIG.md](../dot_claude/RIG.md) | M1 to M16 |
| Codex         | `dot_codex/`  | `~/.codex/`  | `AGENTS.md` | [RIG.md](../dot_codex/RIG.md)  | C1 to C4  |
| Pi            | `dot_pi/`     | `~/.pi/`     | `AGENTS.md` | [RIG.md](../dot_pi/RIG.md)     | P1        |
| Shared skills | `dot_agents/` | `~/.agents/` | None        | [Skills](#skills)              | S1, S2    |

### The rig contract

This document is the overview. Each rig's `RIG.md` is the system design of that rig, and the rig's code follows its `RIG.md`. A difference between a `RIG.md` and the code is a defect. Correct the code or the `RIG.md` in the same change.

A rig's change loop follows one outline: change the source, show `chezmoi diff`, ask the operator, then apply. The rig's `RIG.md` states which steps the model runs and which steps the operator runs.

Each `RIG.md` has these sections in this order: `Use`, `Change the rig`, `Files`, `Checks`, `Limits`. A rig adds its own sections between `Files` and `Checks`, and can add a reference section after `Limits`.

A managed rig is a `dot_<agent>/` submodule that deploys to `~/.<agent>/`. [Private submodules](#private-submodules) holds the branch layout and the hooks. [Deployment and capture](#deployment-and-capture) holds the capture loop and the state that stays unmanaged. Three conditions belong to a rig alone:

- Do not make the target an exact directory. [.chezmoiignore](../.chezmoiignore) keeps unmanaged paths out, but an untracked source file still deploys. A rig that needs a strict boundary uses an allow list. Codex and Pi do.
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

A third-party description is written as if that skill were the only one installed, so the descriptions collide. [SKILLS.md](SKILLS.md) holds the order in which skills compose. The Claude kernel holds the precedence that breaks a tie.

Install a third-party skill with the command above, never by hand. Run `npx skills add <repo> -l` first to read the skill names. Capture one skill directory at a time: a whole-directory add takes the links and the copies with it.

Claude Code frontmatter: `disallowed-tools` removes a tool, and `allowed-tools` is advisory and does not (anthropics/claude-code#37683). A `cmd-*` skill sets `disable-model-invocation: false`. Keep the trigger phrases disjoint across skills. Write a path with forward slashes, never with a backslash. The `whetstone` plugin's `skill-smith` lints the rest.

UNVERIFIED: that Codex loads a skill from `~/.agents/skills` at run time. The Codex binary names that path. `~/.codex/skills/` holds no link to it.

Pi loads every skill under `~/.agents/skills/`. When two skills have the same name, Pi keeps the first and shows a warning. A Pi-only third-party skill goes to `~/.pi/agent/skills/` with `npx skills add <repo> --skill <name> -g -a pi --copy -y`. `dot_pi/skills.tsv` lists those skills for replay.

## Claude Code

| Source                                                                                                  | Owns                                                          |
| ------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| [dot_claude/settings.json](../dot_claude/settings.json)                                                 | Hook wiring, plugins, MCP declarations, statuslines, settings |
| [mods/rig](../dot_claude/mods/rig/), [RIG.md](../dot_claude/RIG.md)                                     | Rig mod: hooks, gates, guard, checks, open items, statusline  |
| [dot_claude/CLAUDE.md](../dot_claude/CLAUDE.md), [rules](../dot_claude/rules/)                          | Kernel and path-scoped instructions                           |
| [agents](../dot_claude/agents/), [skills](../dot_claude/skills/), [workflows](../dot_claude/workflows/) | Delegation contracts and reusable work                        |
| [dot_cavemem/settings.json](../dot_cavemem/settings.json)                                               | Memory configuration. The database stays unmanaged            |
| [rtk config.toml](../Library/private_Application%20Support/private_rtk/config.toml)                     | RTK filters and hook exclusions; `git` is excluded            |

Probe the source and the runtime for model names, plugin revisions, tool inventories, and rule thresholds. A configured key shows intent. The handler and its probe show behavior.

[Skills](#skills) holds the four kinds and the shared store. A common skill reaches Claude through a `symlink_<name>` entry in `dot_claude/skills/` with the content `../../.agents/skills/<name>`. Doctor lint 5e checks the links and the source entries.

### RTK and worktrees

Native `rtk hook claude` is the only RTK command writer. Keep argv in `rtk proxy`. `git` is excluded from the rewrite because the worktree isolation check refuses a rewritten git command (rtk-ai/rtk#3864).

After `EnterWorktree`, the same check also applies to a `!` command that you type. It refuses `git -C ~/<path>`, because it treats `~` as a runtime value. It accepts an absolute path and `"$HOME/<path>"`. Tested with `git status` on 2.1.289 and 2.1.291; `push` is not tested. Rig hooks do not receive `!` commands, so the rig does not cause this refusal and cannot prevent it. When Remote Control is connected, the terminal shows only `detail withheld on this connection`. Start the session with `--debug-file <path>` to read the reason (anthropics/claude-code#99855).

### Plugins, MCP, and memory

First-party plugin source is `~/DEV/rd/claude-code-plugins`. Resolve a deployed file from `installPath` in `~/.claude/plugins/installed_plugins.json`. A cache directory name can be a version, not a SHA. A plugin-registered hook runs outside the rig mod. Disable the plugin in `enabledPlugins` to stop it. Read the manifest and the hook registrations before you enable one.

`settings.json.mcpServers` is canonical. [modify_private_dot_claude.json](../modify_private_dot_claude.json) merges that key into `~/.claude.json` and keeps the other state. Probe drift with `chezmoi-claude-doctor.sh` check 4, which compares the `mcpServers` key alone. Do not use `chezmoi diff ~/.claude.json`: Claude Code writes other keys at run time, and a whole-file diff reports a false drift. Probe connectivity with `claude mcp list`. A duplicate server name at two scopes can split OAuth state.

Cavemem keeps its database under `~/.cavemem`. Do not run `cavemem install` over the managed settings. After an fnm default change, run `chezmoi-claude-bootstrap.sh --only cavemem`. cavemem 0.2.1 pins `better-sqlite3@^11`. Every 11.x aborts in the Node 24 garbage collector with `Assertion failed: (env) != nullptr` ([WiseLibs/better-sqlite3#1515](https://github.com/WiseLibs/better-sqlite3/issues/1515), closed without a fix). On Node 26 the 11.x install script fails, because no prebuild exists and the source does not compile. The bootstrap installs cavemem with `--ignore-scripts`, then installs `better-sqlite3@12.11.1` under cavemem. A manual `npm i -g cavemem` reinstalls 11.x. Run `--only cavemem` after it. Keep the temporary `.npmrc` of `cavemem_pin_bsql` as the only install-script permission for better-sqlite3. npm 11.19 runs an unlisted install script and only warns. If search raises `Maximum call stack size exceeded`, use the timeline and observation tools. Keep native `autoMemoryEnabled` off. A native write creates target drift.

## Codex

`dot_codex/` owns the global instructions, code-style guide, rig reference, native command rules, hook registration, and Python hook source and tests. Read [RIG.md](../dot_codex/RIG.md) for behavior and limits.

Git and chezmoi use explicit file lists for this directory. Keep `config.toml`, authentication, trust records, sessions, databases, logs, generated memories, and plugin caches unmanaged. Do not make `.codex` an exact directory. A new managed file needs an explicit entry in both lists. The exceptions are `docs/` and `archive/`: both lists allow each of these directories whole. `.chezmoiignore` allows `skills/` and keeps Codex's own `.system/` tree out.

The rig documents are managed targets: `PLAN.md`, `docs/`, and `archive/`. Start at the [rig index](../dot_codex/docs/README.md). `docs/AGENT-CASES.md` is the only source-only document. A passing hook suite does not prove live interception. Review new hook definitions with `/hooks`, restart the client, and use disposable fixtures for live checks.

## Operator tools

| Tool                                   | Purpose                                                                                                           |
| -------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `chezmoi-claude-doctor.sh`             | Diagnoses configuration and drift                                                                                 |
| `chezmoi-claude-bootstrap.sh`          | Installs runtime prerequisites. `--check`, `--only`, `--skip`                                                     |
| `cavemem-health.sh`                    | Prints the cavemem problems for the doctor, the bootstrap and `cavemem-repair`. Exit 1 when it finds one          |
| `chezmoi-fixture-check.sh`             | Runs the C4 deployment fixture checks                                                                             |
| `dotfiles-privatize.sh <dir> [--push]` | Moves a source directory to the private repo as branch `<dir>`. Without `--push` it prints the remaining commands |
| `pkill`, `pgrep`                       | Refuses an option that follows the pattern. BSD getopt stops at the first pattern                                 |
| `rig-change-review`, `lens-review`     | Review a rig change, or any other source change                                                                   |

The workflow directory registers scripts through `meta.name`. Operator-only utilities without an automated consumer: `cavemem-seed.ts`, `claude-flag-audit.sh`, `tailscale-mgmt.sh`. `tailscale-mgmt.sh` reads `TAILSCALE_OP_ITEM` from `~/.config/tailscale-mgmt.env`, an encrypted entry.
