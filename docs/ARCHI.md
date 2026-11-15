# How this setup works

This guide covers ownership, load order and constraints for a change to this dotfiles setup. Read versions and inventories from the source files or the tools.

Other documents own these topics:

- [README.md](README.md): install steps and daily commands.
- [MAINTENANCE.md](MAINTENANCE.md): the checks. Its first table selects the checks for a change.
- [SKILLS.md](SKILLS.md): the order in which skills compose.
- [dot_claude/RIG.md](../dot_claude/RIG.md) (private): the internals of the rig.

## Deployment and capture

The source is `~/.dotfiles`. Settings: [.chezmoi.toml.tmpl](../.chezmoi.toml.tmpl). Nothing captures a target on its own.

1. **Change the source.** This is the default. It is the only way for a template, a modify script, an external or a symlink entry.
   1. Edit the file under `~/.dotfiles`.
   1. Run its checks.
   1. Commit in the repository that owns it. A submodule `post-commit` hook commits the gitlink bump in `~/.dotfiles`.
   1. Apply that one target. In a Claude Code session, use `mcp__rig__dotfile_apply <target>`. In a terminal, use `chezmoi apply <target>`.
1. **Capture a target changed in place** (by you, an installer or an app).
   1. Read `chezmoi status` and the target diff.
   1. Show the diff and ask before an agent edits the target.
   1. Validate the target with its own tool.
   1. Run `chezmoi re-add <target>`, read the source diff and commit.
1. **Push.** The operator runs `home push`. It does not reach a repository outside `~/.dotfiles`.

Read `chezmoi status` before a bare `chezmoi re-add`. A bare `re-add` captures every modified target, including an installer or runtime write. If the list holds a change you did not make, capture one target at a time. Revert the rest with `chezmoi apply <target>`.

| Kind                                                                                 | Source                                                              | Maintenance                                         |
| ------------------------------------------------------------------------------------ | ------------------------------------------------------------------- | --------------------------------------------------- |
| File, plain or encrypted                                                             | `dot_`, `private_`, `encrypted_` entries                            | Edit the target and `re-add`. `re-add` re-encrypts  |
| Template                                                                             | `dot_config/glow/glow.yml.tmpl`                                     | Edit the source. `re-add` skips templates           |
| Modify script                                                                        | `modify_private_dot_claude.json`, `dot_claude/modify_settings.json` | Edit the source. It merges into the existing target |
| External                                                                             | [.chezmoiexternal.toml.tmpl](../.chezmoiexternal.toml.tmpl)         | Change the pinned revision or checksum              |
| `README.md`, `AGENTS.md`, `CLAUDE.md`, `docs/`, `tests/`, `install.sh`, `.githooks/` | Repository files                                                    | Edit the source. Not deployed                       |

Before an apply, read `chezmoi status` and `chezmoi diff`. Column one `M` is a target edit. Column one `D` is a deleted target. Do not delete the chezmoi state to resolve drift.

`exact_dot_bin`, `dot_config/exact_zsh` and `dot_config/exact_git` own their target directories. Apply removes an entry there that the source does not hold. Keep generated state elsewhere: completion data in `~/.zfunc`, `~/.zcompdump` and `$XDG_CACHE_HOME/zsh`, plugin checkouts under `$XDG_DATA_HOME/zsh/plugins`.

A `re-add` of an exact directory captures new children and removes source entries for deleted children. Inside an exact directory, a `re-add` of one file also captures new siblings. Inspect the directory before a capture and the source diff after it.

[.chezmoiignore](../.chezmoiignore) controls deployment. Git ignores do not. Its paths are relative to `$HOME`, without a leading `/`. An untracked source file deploys. Do not track authentication, trust records, sessions, databases, logs, caches, installed plugins or app skills. Outside an exact directory, a removed source entry leaves the target in place. Remove that orphan yourself.

Stage a shell startup change with an isolated destination and state file before a broad apply. A broken `.zshrc` affects every new shell.

### Private submodules

`dot_claude/` and `dot_agents/` are git submodules of `raisedadead/dotfiles-private`. Each has its own branch and its own history. Do not change `dot_claude/` without an explicit request.

- A commit inside a submodule runs `.githooks/post-commit`. The hook commits the gitlink bump in `~/.dotfiles` as `chore(<dir>): bump to <sha>`.
- The hook makes no commit when there is no superproject, when the parent is mid-merge or mid-rebase, or when `HEAD` already records the gitlink.
- `.githooks/pre-commit` runs `gitleaks` in both repositories and exits 1 on a finding.
- The parent `.githooks/pre-push` exits 1 when a pushed gitlink commit is on no remote, or when it cannot check it.
- In `dot_gitconfig`, `submodule.recurse` stays `false`. `submodule.<name>.update = merge`. Expected values: [S2](MAINTENANCE.md#s2-private-submodules).
- `status.submoduleSummary` lists a submodule commit that the parent does not record.

To add a private directory, run `dotfiles-privatize.sh <dir> [--push]`. It creates an orphan branch named `<dir>` and seeds the hooks.

## Terminal stack

| Layer       | Source                                                                                | Owns                                                            |
| ----------- | ------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| Desktop     | [AeroSpace](../dot_config/aerospace/aerospace.toml)                                   | Desktop shortcuts, read before the terminal                     |
| Terminal    | [Ghostty](../dot_config/ghostty/config.ghostty)                                       | Rendering, native selection, scrollback, key rewrites           |
| Multiplexer | [tmux](../dot_config/tmux/tmux.conf), [keybindings](../dot_config/tmux/keybinds.conf) | Sessions, panes, popups, root `M-` bindings, editor arbitration |
| Shell       | [zsh](../dot_config/exact_zsh/dot_zshrc)                                              | Emacs editing, completions, history                             |
| Editor      | [Neovim](../dot_config/nvim/)                                                         | LazyVim defaults plus local overrides                           |
| Editor, GUI | [Zed](../dot_config/zed/keymap.json)                                                  | Vim mode; `jj`, `jk`, `kj` and `kk` leave insert mode           |

A root tmux binding takes its key before zsh or Neovim. Before you assign a key, check `ghostty +list-keybinds`, `tmux list-keys -T root` and `bindkey`.

`smart-splits.nvim` sets `@pane-is-vim`. tmux uses it to forward `M-H/J/K/L` to Neovim or to select a pane. The same flag routes the Ghostty Ctrl+Shift+W/E/A/S rewrites: Neovim receives plain Ctrl+W/E/A/S, other panes receive `M-C-w/e/a/s`.

tmux adds client `extkeys` when Ghostty answers XTVERSION. Without that answer, for example over SSH or in nested tmux, the client stays in legacy mode. keybinds.conf keeps legacy and `M-S-` bindings, so each key works in both modes. Check the client features, not only `extended-keys`.

Keep the Ghostty shell-integration feature `path` enabled. Mouse drag selects in tmux. Shift+drag selects in the terminal.

### zsh startup and PATH

- `~/.zshenv` sets `ZDOTDIR` and sources `.config/zsh/.zshenv`. `.zprofile` reapplies PATH after macOS `path_helper`.
- [path.zsh](../dot_config/exact_zsh/path.zsh) prepends in order, so the last prepend wins. [dot_bashrc](../dot_bashrc) carries the fnm prepend too. Keep the two in sync. A GUI process reads no shell startup file and needs its own PATH.
- Keep the `.zshrc` order. fzf-tab loads after compinit and before highlighting and autosuggestions. Atuin loads after fzf and owns Ctrl+R.
- `plugins.lock` records the repository and commit of each plugin. A missing plugin clones at that commit. `zsh-plugin-update` records new pins. Capture the lock after it.
- `rebuild-completions` handles a provider content change. `update-completions` regenerates the gh, op and wrangler providers. Run it after you upgrade those tools.
- chezmoi keeps its packaged `_chezmoi` completion with `completion.custom = false`.
- Ctrl+T replaces the shell argument at the cursor and respects Git ignores. `<C-g>` includes the ignored entries for that call.
- `.zshrc` and `.bashrc` load the worktrunk wrapper with `wt config shell init`. Do not run `wt config shell install`, because it writes the deployed files. An agent shell does not load the wrapper, so `wt switch` cannot change its directory there.
- Keep `DIRENV_LOG_FORMAT` exported above the direnv hook.
- Test Ctrl+L after an OMP update.

### tmux and pickers

- A tmux test server needs a unique `-L` or `-S` on every command, including subprocesses. See [MAINTENANCE.md](MAINTENANCE.md#terminal-stack).
- [theme.conf](../dot_config/tmux/theme.conf) owns the palette and the menu options. Use IDs for menu targets.
- Use tmux `-N` notes for binding descriptions. [keys](../exact_dot_bin/executable_keys) reads tool reports at runtime.
- State the fzf options at each popup call. An inherited `FZF_DEFAULT_OPTS` can change height or truncation.
- [Switcher](../dot_config/tmux/scripts/executable_switcher) is a Bun script, so `bun` must be on the tmux server `PATH`. Its bookmarks are in `$XDG_STATE_HOME/switcher/bookmarks`, one absolute directory per line, unmanaged.
- [reader.sh](../dot_config/tmux/scripts/executable_reader.sh) and [mdr](../exact_dot_bin/executable_mdr) share actions but keep separate fzf bindings. Update both together.
- [input-lib.sh](../dot_config/tmux/scripts/input-lib.sh) needs Homebrew Bash.
- A tmux reload does not clear a removed binding or option. Unbind or unset it explicitly.
- Each script binding calls [run.sh](../dot_config/tmux/scripts/executable_run.sh). It logs child output to `$XDG_STATE_HOME/tmux/<name>.log` and always exits 0 with empty stdout. Without it, a `run-shell` that writes to stdout puts the pane in view mode.
- Add `-b` to `run-shell` only when the child opens a menu or a popup. Quote each format that becomes a shell word with `#{q:...}`.

### Neovim

[lua/config](../dot_config/nvim/lua/config/) holds LazyVim deltas. [lua/plugins](../dot_config/nvim/lua/plugins/) holds plugin overrides. [lazyvim.json](../dot_config/nvim/lazyvim.json) selects the extras. Use `catppuccin-mocha`. Plugin update checks are off. Run `:Lazy update`, then `chezmoi re-add ~/.config/nvim/lazy-lock.json`.

### Rex

[dot_config/rex](../dot_config/rex/) holds the Rex terminal config. [init.lua](../dot_config/rex/init.lua) loads `lib.lua`, then one Lua module for each feature. [bin](../dot_config/rex/bin/) holds the helper scripts. `rex-open FILE[:LINE[:COL]]` opens the editor in a new tab of the current session. Outside Rex it runs the editor in place.

Rex and Ghostty with tmux are both daily terminals. Each Rex path in a shared file is behind one gate: `[[ $TERM_PROGRAM == rex && -n $REX_SESSION && -z $TMUX ]]`. Outside the gate, zsh, `keys` and `mdr` behave as before.

- zsh reports a command that runs `REX_STATUS_MIN` seconds or more (default 15) as an OSC 7501 record. [rex.zsh](../dot_config/exact_zsh/rex.zsh) holds the skip lists: `REX_STATUS_SKIP`, `REX_STATUS_PAGER`, `REX_STATUS_REPL` and `REX_STATUS_AGENTS`.
- **Agent Here** starts Claude Code in a new pane. The managed hooks give it the text of `rex __internal session-start` and keep a restore record in `~/.local/state/rex/agents`.
- [run_onchange_before_rex-config-check.sh.tmpl](../run_onchange_before_rex-config-check.sh.tmpl) runs `rex config check` when a module changes and stops the apply on an error. Reload: [README.md](README.md#rex).
- [run_onchange_after_rex-defaults.sh.tmpl](../run_onchange_after_rex-defaults.sh.tmpl) writes the Rex app settings with `defaults write com.superlogical.rex`. The source owns each key that it writes. It merges [custom-themes.json](../dot_config/rex/themes/custom-themes.json) into `Workspace.customThemes` by id and never deletes a theme. The same script installs the `xterm-rex` terminfo entry with `rex terminfo setup --entry-only`.
- The rig guard refuses input to a block on the live Rex server. An agent types only on a `-S` sandbox server under `/tmp`. `REX_SERVER` that does not answer makes `rex` use the live server. An explicit `-S` fails instead.
- The `rex-handoff` command opens a float where the operator approves a command. It then runs the command in an interactive `zsh`. `REX_HANDOFF` makes the zsh setup skip plugin install and completion rebuild.

Check a change with `rex config check`, [tests/rex/sandbox.sh](../tests/rex/sandbox.sh) and [tests/rex/gate.sh](../tests/rex/gate.sh). The sandbox test starts its own server. [testkit.lua](../tests/rex/testkit.lua) adds the test actions to its copy of the config. [rex-guard.sh](../tests/rex/rex-guard.sh) refuses another server. Set `REX_GUARD_STRICT=1` to also refuse a call without `-S`. Put the checks for one feature in `tests/rex/cases/<feature>.sh`.

## Desktop

AeroSpace and SketchyBar share workspace names across `aerospace.toml`, `sketchybar/lua/items/spaces.lua` and the bracket in `sketchybarrc`. Update the three together. A GUI-launched rule script needs absolute executable paths. `ctrl-alt-w` runs `aeroplace layout`, which serializes layout changes with `lockf`. Keep `outer.bottom` scalar in the TOML, because `aeroplace` reads it with a line match.

Set AeroSpace `outer.bottom` to the bar height plus its bottom inset plus the window gap: `30 + 6 + 8 = 44`. Keep `background.height` and `corner_radius` the same in `sketchybarrc`, `lua/items/front_app.lua` and `lua/items/widgets.lua`. After a height or offset change, run `sketchybar --query bar` and check the screen geometry before you change the AeroSpace bottom gap.

## Claude Code

Claude Code is the only agent rig. It owns its kernel and its runtime. `dot_agents/` (target `~/.agents/`) is the shared skill layer. The operator owns releases and infrastructure changes.

| Source                                                                              | Owns                                                                         |
| ----------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| [dot_claude/.settings.managed.json](../dot_claude/.settings.managed.json)           | Hook wiring, plugins, MCP declarations, statuslines, settings                |
| [mods/rig](../dot_claude/mods/rig/), [RIG.md](../dot_claude/RIG.md)                 | Rig mod: hooks, gates, guard, write approval, checks, open items, statusline |
| [dot_claude/CLAUDE.md](../dot_claude/CLAUDE.md), [rules](../dot_claude/rules/)      | Kernel and path-scoped instructions                                          |
| [agents](../dot_claude/agents/), [skills](../dot_claude/skills/)                    | Delegation contracts and reusable work                                       |
| [dot_cavemem/settings.json](../dot_cavemem/settings.json)                           | Memory configuration. The database stays unmanaged                           |
| [rtk config.toml](../Library/private_Application%20Support/private_rtk/config.toml) | RTK filters and hook exclusions; `git` is excluded                           |

Probe the source and the runtime for model names, plugin revisions, tool inventories and rule thresholds. A configured key shows intent. The handler and its probe show behavior.

[MAINTENANCE.md](MAINTENANCE.md#choose-checks-for-your-change) selects the checks for a change. Each rig-guard check matches command text and needs `shfmt` to read shell syntax. The guard is not a sealed boundary.

### Rig behavior

- `dotfile_apply` applies named targets. It opens a dialog with the diff only when a changed file is a rig gate or hook, a secret or encrypted file, a git, shell, ssh or `wt` file, a file in `~/.bin`, or a run script. The operator's answer is the approval. `chezmoi apply <target>` run alone opens the dialog for every target.
- `ship` pushes a branch and opens its PR after one dialog. A PR has a title only.
- The rig rescans unpushed commits at each main-session turn, after `git` or `gh` runs, and when a helper ends.
- A role helper gets its allowed shell commands at SubagentStart.

### Skills

| Kind     | Home                                             | Reaches                                                                                         |
| -------- | ------------------------------------------------ | ----------------------------------------------------------------------------------------------- |
| Personal | `dot_claude/skills/<name>/`                      | Claude Code alone                                                                               |
| Common   | `dot_agents/skills/<name>/`                      | A `symlink_<name>` entry in `dot_claude/skills/` with the content `../../.agents/skills/<name>` |
| App      | The app setup command, such as `rex skill setup` | An unmanaged copy under `~/.agents/skills/`, linked from `~/.claude/skills/`                    |
| Plugin   | Its plugin                                       | Never linked                                                                                    |

First-party skills have two prefixes. `cmd-` means the operator usually starts the skill. `rig-` means the model loads the skill on its own.

- Personal: `cmd-status`, `cmd-continue`, `cmd-handoff`, `cmd-recall`, `cmd-wrist-tap`, `cmd-refresh-plugins`, `cmd-watch-pane`, `cmd-audit-kernel`, `cmd-audit-scratchpad`, `rig-plan`, `rig-secrets`, `rig-chezmoi`, `rig-docs`.
- Common: `cmd-add-skill`, `cmd-ghsa`.

There are no third-party skills. `docs/skills.tsv` is empty. [SKILLS.md](SKILLS.md) holds the order in which skills compose.

Frontmatter: `disallowed-tools` removes a tool. `allowed-tools` is advisory and does not (anthropics/claude-code#37683). Keep the trigger phrases disjoint across skills. Write a path with forward slashes. The `whetstone` plugin `skill-smith` lints the rest. Doctor lint 5e checks the skill links and the source entries.

### Project instructions

Claude Code reads `CLAUDE.md` and does not read `AGENTS.md`. In this repository, `CLAUDE.md` is a symlink that holds `AGENTS.md`. A global kernel is not a project file.

### Workspace

Each project has one workspace: `<repo>/.scratchpad/` of the main checkout when Git ignores it, else `~/.scratchpad/`. A linked worktree uses the workspace of its main checkout. A submodule is its own project.

| Name           | Holds                                                   |
| -------------- | ------------------------------------------------------- |
| `OPEN-WORK.md` | The open-work list                                      |
| `LINKED`       | Paths of related projects, one on each line             |
| `handoff/`     | `<date>-<slug>.md` handoffs                             |
| `tmp/`         | `<date>-<slug>/` scratch output and notes files         |
| `research/`    | Research reports                                        |
| `plans/`       | Plans, always in the project folder                     |
| `dossier/`     | Dossiers and their archive, owned by the dossier plugin |
| `_archive/`    | Moved files and closed rows                             |

At `startup` and `clear`, the rig builds a status note from the workspace files and Git. The note lists the handoffs, the lines in progress, the lines that wait on the operator, the paused lines and the unpushed work. It adds one line for each project in `LINKED`. If the note takes more than 2 seconds, the session starts with what is ready.

### Worktrees and RTK

A session starts in the main checkout and works in `wt` worktrees by full path. After `EnterWorktree`, Claude Code refuses an edit to the main checkout. Branch form: `<type>/cc-<first 6 of session ID>-<topic>`.

`dot_config/worktrunk/private_config.toml` sets `[merge] remove = false` and excludes `.scratchpad/` from `wt step copy-ignored`. The guard asks before a worktree removal through `wt` or `git` (`mods/rig/src/mutations.ts`). The `worktree_remove` tool asks only when `force` or `force_delete` would drop uncommitted files or unmerged commits.

Native `rtk hook claude` is the only RTK command writer. Keep argv in `rtk proxy`. `git` is excluded from the rewrite, because the worktree check refuses a rewritten git command (rtk-ai/rtk#3864).

After `EnterWorktree`, the same check refuses a typed `!` command `git -C ~/<path>` (anthropics/claude-code#88550). Use an absolute path or `"$HOME/<path>"`. When Remote Control is connected, start the session with `--debug-file <path>` to read the refusal reason.

### Plugins, MCP and memory

- First-party plugin source is `~/DEV/rd/claude-code-plugins`. Resolve a deployed file from `installPath` in `~/.claude/plugins/installed_plugins.json`.
- A plugin hook runs outside the rig mod. Disable the plugin in `enabledPlugins` to stop it. Read the manifest and the hook registrations before you enable a plugin.
- The rig (gate and validator reminders) and the dossier plugin (the wave contract line) add hidden context to a prompt. They do not coordinate and have no cap.
- The worktrunk plugin `PermissionRequest` hook approves `EnterWorktree` outside the rig guard. This is an accepted gap.
- `settings.json.mcpServers` is canonical. [modify_private_dot_claude.json](../modify_private_dot_claude.json) merges that key into `~/.claude.json` and keeps the other state. Probe drift with `chezmoi-claude-doctor` check 4. Do not use `chezmoi diff ~/.claude.json`. Probe connectivity with `claude mcp list`.
- Cavemem is removed. Its data stays in `~/.cavemem` until the operator chooses a replacement.

### Rig metrics

[rig-metrics](../exact_dot_bin/executable_rig-metrics) reads the transcripts under `~/.claude/projects`, prints JSON and writes nothing. `rig-metrics [--until YYYY-MM-DD] [days]` prints two numbers for each ISO week of the window (30 days by default), and a total:

- `correctionsPer100`: operator corrections for each 100 operator messages. The `CORRECTION` pattern in the script lists the correction words.
- `refusalsPer100`: rig refusals for each 100 tool results. A refusal is a failed tool result that a hook, the guard or the permission layer wrote.

Probe sessions do not count. Check: [G1](MAINTENANCE.md#g1-rig-metrics).

## Operator tools

| Tool                                   | Purpose                                                                                                                                                                                     |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `chezmoi-claude-doctor`                | Diagnoses configuration and drift. `--rewake` writes warnings to `~/.claude/markers/doctor-warnings.txt`. On a new Claude Code version it re-tests the rig mod. See [M1](MAINTENANCE.md#m1) |
| `chezmoi-claude-bootstrap.sh`          | Installs runtime prerequisites. `--check`, `--only`, `--skip`                                                                                                                               |
| `claude-flag-audit.sh [days] [-v]`     | Lists safeguard `model_refusal_fallback` events in the Claude transcripts. The doctor calls it                                                                                              |
| `chezmoi-fixture-check.sh`             | Runs the S3 deployment fixture checks                                                                                                                                                       |
| `dotfiles-privatize.sh <dir> [--push]` | Moves a source directory to the private repo as branch `<dir>`. Without `--push` it prints the remaining commands                                                                           |
| `pkill`, `pgrep`                       | Refuses an option that follows the pattern                                                                                                                                                  |

The doctor warns about each agent addition that the source and [agent-additions.txt](agent-additions.txt) do not hold, and about a link in `~/.bin` or `~/.claude/skills` to a missing file. It runs at each new Claude Code session start, and the statusline shows the warning count. It detects an item after the write and does not block it. An edit to the approved list shows in `git status`, not as a warning.
