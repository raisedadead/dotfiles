# How this setup works

This guide holds the ownership, the load order, and the constraints for a change. Read versions, revisions, and inventories from the source files or the tools.

## Deployment and capture

Edit the target. Validate it. Run `chezmoi status`, then `chezmoi re-add <target>`. Inspect the Git diff. Commit. Nothing captures a target on its own. A rig file follows the change loop in its rig's `RIG.md` instead. Settings: [.chezmoi.toml.tmpl](../.chezmoi.toml.tmpl).

Read `chezmoi status` before a bare `chezmoi re-add`. A bare `re-add` captures every modified target, including an installer or runtime write. Capture one target at a time when the list holds a change you did not make. Revert the rest with `chezmoi apply <target>`.

| Kind                                                                                 | Source                                                                                                   | Maintenance                                         |
| ------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| File, plain or encrypted                                                             | `dot_`, `private_`, `encrypted_` entries                                                                 | Edit the target and `re-add`. `re-add` re-encrypts  |
| Template                                                                             | `dot_config/glow/glow.yml.tmpl`, `dot_pi/agent/mcp.json.tmpl`                                            | Edit the source. `re-add` skips templates           |
| Modify script                                                                        | `modify_private_dot_claude.json`, `dot_claude/modify_settings.json`, `dot_pi/agent/modify_settings.json` | Edit the source. It merges into the existing target |
| External                                                                             | [.chezmoiexternal.toml](../.chezmoiexternal.toml)                                                        | Change the pinned revision or checksum              |
| `README.md`, `AGENTS.md`, `CLAUDE.md`, `docs/`, `tests/`, `install.sh`, `.githooks/` | Repository files                                                                                         | Edit the source. Not deployed                       |

`re-add` does not capture templates, modify targets, externals, or symlink entries. Before an apply, read `chezmoi status` and `chezmoi diff`. Column one `M` is a target edit. Column one `D` is a deleted target. Do not delete the chezmoi state to resolve drift.

`exact_dot_bin`, `dot_config/exact_zsh`, and `dot_config/exact_git` own their target directories. Apply removes an entry there that the source does not hold. Keep generated state elsewhere. Completion data lives in `~/.zfunc`, `~/.zcompdump`, and `$XDG_CACHE_HOME/zsh`. Plugin checkouts live under `$XDG_DATA_HOME/zsh/plugins`.

A `re-add` of an exact directory captures new children and removes source entries for deleted children. Inside an exact directory, a `re-add` of one child file also captures new siblings; outside one it takes the named file only (`chezmoi-fixture-check.sh` check 6 asserts both). Inspect the directory before a capture and the source diff after it.

[.chezmoiignore](../.chezmoiignore) controls deployment. Git ignores do not. Its paths are relative to `$HOME`, without a leading `/`. An untracked source file deploys. Do not track authentication, trust records, sessions, databases, logs, caches, generated memories, installed plugins, or the links of third-party and app skills. Outside an exact directory, a removed source entry leaves the target in place. Remove that orphan yourself.

Stage a shell startup change with an isolated destination and state file before a broad apply. A broken `.zshrc` affects every new shell.

### Private submodules

`dot_claude/`, `dot_agents/`, and `dot_pi/` are git submodules of `raisedadead/dotfiles-private`, one branch each, with independent history. A commit inside a submodule runs its `.githooks/post-commit`, which commits the gitlink bump in `~/.dotfiles` as `chore(<dir>): bump to <sha>`. The hook exits 0 without a commit when there is no superproject, when the parent is mid-merge or mid-rebase, or when `HEAD` already records the gitlink. When the parent tip is a bump that no remote holds, the hook amends it. `status.submoduleSummary` lists a submodule commit the parent does not record yet.

Both repos run `gitleaks` in `.githooks/pre-commit` and exit 1 on a finding. The parent `.githooks/pre-push` resolves the gitlink of each commit in each pushed range. It exits 1 when that submodule commit is on no remote, or when it cannot check it. A clone of the parent cannot check out such a commit.

In `dot_gitconfig`, `submodule.recurse` stays `false`: `true` lets `pull`, `checkout`, `switch`, and `reset` rewind the submodule working tree. `submodule.<name>.update = merge` makes `git submodule update` a no-op while the branch is ahead. Expected values: [S2](MAINTENANCE.md#s2-private-submodules).

Each private directory is one orphan branch named after the directory, mounted with `git submodule add -b <dir>`. `dotfiles-privatize.sh` seeds `.githooks/pre-commit` and `post-commit` into a new branch.

## Terminal stack

| Layer       | Source                                                                                | Owns                                                            |
| ----------- | ------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| Desktop     | [AeroSpace](../dot_config/aerospace/aerospace.toml)                                   | Desktop shortcuts, read before the terminal                     |
| Terminal    | [Ghostty](../dot_config/ghostty/config.ghostty)                                       | Rendering, native selection, scrollback, key rewrites           |
| Multiplexer | [tmux](../dot_config/tmux/tmux.conf), [keybindings](../dot_config/tmux/keybinds.conf) | Sessions, panes, popups, root `M-` bindings, editor arbitration |
| Shell       | [zsh](../dot_config/exact_zsh/dot_zshrc)                                              | Emacs editing, completions, history                             |
| Editor      | [Neovim](../dot_config/nvim/)                                                         | LazyVim defaults plus local overrides                           |
| Editor, GUI | [Zed](../dot_config/zed/keymap.json)                                                  | Vim mode; `jj`, `jk`, `kj` and `kk` leave insert mode           |

A root tmux binding takes its key before zsh or Neovim. Before you assign a key, check `ghostty +list-keybinds`, `tmux list-keys -T root`, and `bindkey`. Ghostty Alt+Left/Right send `M-b`/`M-f`.

`smart-splits.nvim` sets `@pane-is-vim`. tmux uses it to forward `M-H/J/K/L` to Neovim or to select a pane. The same flag routes Ghostty's Ctrl+Shift+W/E/A/S rewrites: Neovim receives plain Ctrl+W/E/A/S, other panes receive `M-C-w/e/a/s`. Ctrl+Shift+W deletes to line start in zsh.

tmux adds client `extkeys` when Ghostty answers XTVERSION, and then requests modifyOtherKeys mode 2. tmux.conf does not list `extkeys`. Without that answer, for example over SSH or in nested tmux, the client stays in legacy mode. keybinds.conf keeps legacy uppercase plus `M-S-` bindings, so each left-Option+Shift key works in both modes. `terminal-features` resets before it appends, so a reload does not duplicate entries. Check the client features, not only `extended-keys`.

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

`.zshrc` and `.bashrc` load the worktrunk wrapper with `wt config shell init`. Do not run `wt config shell install`, because it writes the deployed files. An agent shell does not load the wrapper, so `wt switch` cannot change its directory there. See [RTK and worktrees](#rtk-and-worktrees).

Keep `DIRENV_LOG_FORMAT` exported above the direnv hook.

OMP cache cleanup matches UUID session caches only. Do not include `init.*.zsh` or bare `omp.cache`. Keep the array slice `"${(@)_c[51,-1]}"`. Without `(@)` the slice joins the paths and removes nothing.

An empty, forced, left-aligned OMP block precedes the main prompt. It preserves the main block's newline on the first prompt, on row 1, and after `clear` or Ctrl+L. Each prompt gets one blank line above it. `enable_cursor_positioning` reads the row before each prompt. A slow reply to that query can show as `^[[NN;1R` on the command line. Ctrl+L redraws through the internal `_omp_get_prompt primary --cleared`. Test it after an OMP update.

### tmux and pickers

A tmux test server needs a unique `-L` or `-S` on every command, including subprocesses. It follows the probe rules in [MAINTENANCE.md](MAINTENANCE.md#terminal-stack).

[theme.conf](../dot_config/tmux/theme.conf) owns the palette and the menu options. Use IDs for menu targets. Escape displayed names. Command-local menu colors are literal. Global menu style options accept formats. A painted popup background is opaque, also with Ghostty transparency.

Use tmux `-N` notes for binding descriptions. [keys](../exact_dot_bin/executable_keys) reads tool reports at runtime. State the fzf options at each popup call, because an inherited `FZF_DEFAULT_OPTS` can change height or truncation. `--keep-right` also truncates headers and footers from the left. Test the real popup width.

[Switcher](../dot_config/tmux/scripts/executable_switcher.sh) rows carry the target path apart from the display text. Its bookmarks live unmanaged at `$XDG_STATE_HOME/switcher/bookmarks`, one absolute directory per line.

[reader.sh](../dot_config/tmux/scripts/executable_reader.sh) and [mdr](../exact_dot_bin/executable_mdr) share actions through mdr subcommands but keep separate fzf bindings. Update both together. Rows are NUL-delimited with the path after the first tab. Sanitize only the display text. A positive ripgrep glob is an inclusion rule. Off-repository walks stop at depth six.

Force color and pager options in previews. bat and glow behave differently off a TTY. Glow does not expand `~` in its style path, so its configuration is a template. Keep the temporary-file removal before `exec glow`. An EXIT trap does not run after exec.

[input-lib.sh](../dot_config/tmux/scripts/input-lib.sh) needs Homebrew Bash for namerefs.

A tmux reload adds or overwrites bindings and options. A removed source line does not clear runtime state. Unbind or unset explicitly. A `run-shell` string expands formats before the child command. Double `#` when the inner command needs the format. `M-\\` cannot be a menu shortcut, because ESC-backslash ends a DCS ([tmux issue](https://github.com/tmux/tmux/issues/4386)).

`run-shell` puts the pane in view mode when the child writes to stdout, or when the child exits non-zero. Stderr alone is safe. That pane then ignores keys until `q`, which reads as a frozen session. Each script binding therefore calls [run.sh](../dot_config/tmux/scripts/executable_run.sh), which sends the child output to `$XDG_STATE_HOME/tmux/<name>.log`, shows a message on a non-zero exit, and always exits 0 with empty stdout. Do not use `|| true`: it corrects the exit code and not the stdout.

Add `-b` only when the child opens a menu or a popup, because a blocking `run-shell` holds the client command queue until the child stops. `-b` also removes the serialization, so repeated presses of a key that cycles race. Quote each format that becomes a shell word with `#{q:...}`. A plain `'#{pane_current_path}'` runs arbitrary commands from a directory name that contains an apostrophe.

### Neovim

[lua/config](../dot_config/nvim/lua/config/) holds LazyVim deltas. [lua/plugins](../dot_config/nvim/lua/plugins/) holds plugin overrides. [lazyvim.json](../dot_config/nvim/lazyvim.json) selects the LazyVim extras. Check the upstream default before you add one. Use `catppuccin-mocha`. Bare `catppuccin` can resolve to the built-in colorscheme.

`chezmoi.nvim` does not watch source buffers. The whitespace autocmd trims selected code and config filetypes only. It keeps Markdown and plain text, and it skips binary, special, nonmodifiable, and large buffers. Keep it separate from a conform catch-all formatter, which suppresses the LSP fallback.

Plugin update checks are off. Run `:Lazy update`, then `chezmoi re-add ~/.config/nvim/lazy-lock.json`. `:Lazy sync` also removes plugins absent from the spec.

### Rex

[dot_config/rex](../dot_config/rex/) holds the Rex terminal config. [init.lua](../dot_config/rex/init.lua) loads the shared helpers in `lib.lua`, then one Lua module for each feature: popups, the drawer, workspaces, the hand-off float, the agent actions, and the keys. [bin](../dot_config/rex/bin/) holds the helper scripts that the actions and `mdr` start. `rex-open FILE[:LINE[:COL]]` opens the editor in a new tab of the current session. Outside Rex it runs the editor in place. `mdr --edit` and the reader popup use it.

Rex and Ghostty with tmux are both daily terminals. Neither replaces the other. Each Rex path that this setup adds to a shared file is behind one gate: `[[ $TERM_PROGRAM == rex && -n $REX_SESSION && -z $TMUX ]]`. Outside the gate, zsh, `keys`, `mdr` and the session recorder hook behave as before. tmux inside a Rex pane fails the gate, so the tmux paths stay in use there.

zsh reports a command that runs `REX_STATUS_MIN` seconds or more (default 15) as an OSC 7501 `done` or `error` record with `app=<program>`. The next command clears it. [rex.zsh](../dot_config/exact_zsh/rex.zsh) holds its own copy of the gate. It skips interactive programs (`REX_STATUS_SKIP`), pagers at the end of a pipeline (`REX_STATUS_PAGER`), bare REPLs (`REX_STATUS_REPL`), commands that name an agent (`REX_STATUS_AGENTS`), an interrupted or stopped command, and `git commit` when it opens an editor. Aliases and git aliases expand before the match; heredoc bodies are ignored.

Ctrl+Enter sends Enter, as in Ghostty. In a Claude Code pane it sends Ctrl+J, which adds a new line. Ctrl+Shift+K and Ctrl+Shift+J scroll one page up and down; in Ghostty the same keys scroll 5 lines. Cmd+PageUp and Cmd+PageDown also scroll one page, as in Ghostty. Cmd+Up and Cmd+Down jump to the previous and the next prompt (Rex default). Rex has no line, top or bottom scroll action ([feedback](https://discord.com/channels/1546797889009881158/1565009888235622462)).

**Agent Here** starts Claude Code in a new pane, and **Agent Here (Pi)** starts Pi. In Rex, each agent gets the text of `rex __internal session-start` at session start and keeps a restore record in `~/.local/state/rex/agents`. For Claude Code, the managed hooks do this. For Pi, the [rex-session](../dot_pi/agent/extensions/rex-session.ts) extension does it in the interactive TUI only. Pi saves its session file after the first message, so the record waits for it.

[run_onchange_before_rex-config-check.sh.tmpl](../run_onchange_before_rex-config-check.sh.tmpl) runs `rex config check` on the source when a module changes and stops the apply on an error. Without the `rex` CLI it does nothing. Reload: [README.md](README.md#rex).

Rex restores a block without its command, so a restored block runs a login shell. `agents_resume` uses that to find the restored popups, hand-off floats and `editor` panes.

[run_onchange_after_rex-defaults.sh.tmpl](../run_onchange_after_rex-defaults.sh.tmpl) writes the Rex app settings with `defaults write com.superlogical.rex`. The source owns each key it writes. When the script or [custom-themes.json](../dot_config/rex/themes/custom-themes.json) changes, the script replaces an app change to an owned key. The script merges the theme file into `Workspace.customThemes` by id (the first theme is the dark theme) and never deletes a theme: to remove one, delete it from the file and in Rex Settings. On bad input it writes nothing and prints a `rex-defaults:` message. To capture app themes: `defaults export com.superlogical.rex /tmp/rex.plist`, then `/usr/libexec/PlistBuddy -c 'Print :Workspace.customThemes' /tmp/rex.plist | jq . > dot_config/rex/themes/custom-themes.json`. A capture makes the source own all app themes.

The same script installs the `xterm-rex` terminfo entry with `rex terminfo setup --entry-only`. A plain setup adds an `Include` line to `~/.ssh/config`, which chezmoi owns. `SetEnv TERM=xterm-256color` in that file already keeps the name off ssh hosts.

Both rig guards refuse input to a block on the live Rex server, so an agent types only on a `-S` sandbox server under `/tmp`. On the live server `rex do` runs only the actions on the short list in each guard, and no Lua. An agent cannot stop the live server or run `agents_resume`. [dot_claude/RIG.md](../dot_claude/RIG.md) and [dot_pi/RIG.md](../dot_pi/RIG.md) list the rest. `.chezmoiremove` deletes the global `rex` skill that `rex skill setup` installs. The `rex-handoff` skill is off in the managed Claude Code settings; the `rex-handoff` script still opens a float where the operator approves a command, then runs it in an interactive `zsh`. `REX_HANDOFF` makes the zsh setup skip plugin install and completion rebuild. A zsh function or builtin runs in place of a program of the same name. A directory change does not reach the agent's pane.

A `REX_SERVER` socket that does not answer makes `rex` use the live server; an explicit `-S` fails instead. A script gives `REX_SERVER` to `rex` as `-S`.

Check a change with `rex config check`, [tests/rex/sandbox.sh](../tests/rex/sandbox.sh) and [tests/rex/gate.sh](../tests/rex/gate.sh). The sandbox test starts its own server, and [testkit.lua](../tests/rex/testkit.lua) adds the test actions to its copy of the config. A `rex` guard on its `PATH` sends each call to that server and refuses another server, so the test does not touch the live Rex session. With `REX_GUARD_STRICT=1`, the guard also refuses a call that has no `-S` (`tests/rex/rex-guard.sh:25`). Set it on a helper check, so that the check fails while the helper does not give `-S`. Put the checks for one feature in `tests/rex/cases/<feature>.sh`; the sandbox test sources each file.

## Desktop and utilities

AeroSpace and Sketchybar share workspace names across `aerospace.toml`, `sketchybar/lua/items/spaces.lua`, and the bracket in `sketchybarrc`. Update the three together. Read layout keys and triggers from the AeroSpace source. An unmatched window follows the floating catch-all rule. A GUI-launched rule script needs absolute executable paths. `ctrl-alt-w` runs `aeroplace layout`, which serializes layout changes with `lockf`. Keep `outer.bottom` scalar in the TOML, because `aeroplace` reads it with a line match.

Set AeroSpace `outer.bottom` to the bar height plus its measured bottom inset plus the window gap: `30 + 6 + 8 = 44`. `y_offset = 3` raises the bar 6 pt. AeroSpace already excludes the native menu bar from its work area.

Keep `background.height` and `corner_radius` the same in `sketchybarrc`, `lua/items/front_app.lua`, and `lua/items/widgets.lua`. After a height or offset change, run `sketchybar --query bar` and check the screen geometry before you change the AeroSpace bottom gap ([SketchyBar properties](https://felixkratz.github.io/SketchyBar/config/bar)).

Shell helpers use `_mrgsh_` internal names and `can_haz` for optional tools. `executable_` marks a program, not a sourced file. `awake` stores PID, deadline, and spec state. Its process check cannot tell a reused PID from another `caffeinate`.

## Agent rigs

Two coding agents run on this machine. Each owns its own global kernel and its own runtime. One agent edits the other's kernel only when the operator asks. This repository is the source of truth for what they share: where a rig deploys, what stays unmanaged, and how a skill reaches each agent.

| Rig           | Source        | Target       | Kernel      | System design                  |
| ------------- | ------------- | ------------ | ----------- | ------------------------------ |
| Claude Code   | `dot_claude/` | `~/.claude/` | `CLAUDE.md` | [RIG.md](../dot_claude/RIG.md) |
| Pi            | `dot_pi/`     | `~/.pi/`     | `AGENTS.md` | [RIG.md](../dot_pi/RIG.md)     |
| Shared skills | `dot_agents/` | `~/.agents/` | None        | [Skills](#skills)              |

[MAINTENANCE.md](MAINTENANCE.md#choose-checks-for-your-change) selects the checks for a change.

### The rig contract

This document is the overview. Each rig's `RIG.md` is the system design of that rig, and the rig's code follows its `RIG.md`. A difference between a `RIG.md` and the code is a defect. Correct the code or the `RIG.md` in the same change.

The same command gets the same outcome in the Claude Code and Pi rigs: it runs, it asks, or it is denied. The prompts have the same options. Each rig keeps its own code, and no UI code moves between rigs. These differences stay:

- The Pi guard denies each `pi` command from the model, because a child session from bash skips the agent contract. The Claude guard lets it run.
- The Claude guard denies `cp ~/.ssh/id_*`. The Pi guard lets it run.
- The skill-order check sees a Claude `Skill` call, and in Pi a read of a `better-*/SKILL.md` file. A `/skill:` command that the operator types in Pi records the skill and is never refused.
- The Pi guard checks a heredoc body for its deny patterns. It skips the body only when the heredoc is quoted, nothing on its line or before it opens a `{`, `(` or backtick, and the last command on its line is `cat` with at most one file redirect, or `tee` with files. The Claude guard reads a body as commands when a shell, `ssh`, `eval`, `at`, `batch`, `script`, `xargs`, `parallel` or `crontab` runs on its line, or when a shell name with only flags comes just before the heredoc. It checks every other body for the deny patterns and secret sinks. Both guards treat input piped to `at` or `batch` as a command built at run time.
- Outside Rex (no `REX_BLOCK`), the Claude guard refuses each `rex` command that reaches the live server, such as `rex capture`. The Pi guard lets a verified read run. Only the Claude guard refuses a `rex kill` or a `rex session kill` of more than one session.
- A long Claude dialog offers `Details`, which opens the `Approval` view. A long Pi dialog offers `Show all text`.
- Pi reads an optional local `~/.pi/agent/redact.json` that adds or turns off redaction rules. Claude has no such file.
- The kernels differ where the tools differ. Pi has no advisor, TaskList or `notebook`, and its `agent` tool runs one child at a time. Claude has no copy of Pi's `07-owasp`, `55-pytest` and `65-go-testing` rules.
- [SKILLS.md](SKILLS.md) uses Claude names, except in the UI workflow.

Each `RIG.md` holds the limits of its rig. The guards match command text and need `shfmt` to read shell syntax. They are not a sealed boundary.

In each rig, `chezmoi apply <target>` run alone opens a dialog with the diff, and the operator's answer is the approval. Each `RIG.md` states which steps the model runs.

Each `RIG.md` has these sections in this order: `Use`, `Change the rig`, `Files`, `Checks`, `Limits`. A rig adds its own sections between `Files` and `Checks`, and can add a reference section after `Limits`.

A managed rig is a `dot_<agent>/` submodule that deploys to `~/.<agent>/`. [Private submodules](#private-submodules) holds the branch layout and the hooks. [Deployment and capture](#deployment-and-capture) holds the capture loop and the state that stays unmanaged. Three conditions belong to a rig alone:

- Do not make the target an exact directory. [.chezmoiignore](../.chezmoiignore) keeps unmanaged paths out, but an untracked source file still deploys. A rig that needs a strict boundary uses an allow list. Pi does.
- [MAINTENANCE.md](MAINTENANCE.md) holds a check row for the rig.
- The rig's own kernel or its chezmoi rule names this document, which links [AGENTS.md](../AGENTS.md) and the rest. One pointer is enough.

To add a rig: run `dotfiles-privatize.sh <dir>`, add the rig's entries to [.chezmoiignore](../.chezmoiignore), add a row to the table above, and add the check row.

### Second review

Both rigs ask Jev, the TypeSafe classifier, whether a change needs a second review. The question file [second-review.json](../dot_agents/jev/second-review.json) deploys to `~/.agents/jev/second-review.json`. It holds the pinned Jev model, the 1Password key reference, the time limit, the bands, the three topics (guard or permission rule, secret handling, deploy or release) and the `enforce` flag. Both rigs read it.

- Each rig sends the changed paths to Jev at the end of a turn, with one question for each topic and path. Jev gets no file content. The highest answer for a path decides. A change to the question file counts as a guard change.
- At or above `bands.block`, two reviews must cover the path. The Claude rig blocks Stop; the Pi rig continues the turn. From `bands.note` up to the block line, the rig tells the model which file can need care.
- The rig asks Jev once for each new set of paths. A fix to covered paths does not ask again.
- Jev only adds care. No key, no network, a timeout, a failed `op read` or a bad question file means Jev is down: the status line shows `jev off`, the rig stores no answer and asks for those paths again later, and the kernel review rule applies. Answers stored before stay in force.
- With `enforce: false`, the rigs ask Jev and log the answer. They do not block, send a note or show the `2nd review` status. The status line still shows `jev off` while Jev is down.
- Each rig keeps the question file it loaded for the rest of the session. A change to `enforce` takes effect at the next session start or resume. If the file did not load, the rig tries again at the end of each turn.
- Each rig reads the key with `op read`. `auth.json` stays unmanaged.
- Both rigs append each decision to `~/.local/state/jev/decisions.jsonl`, mode 600, in a folder of mode 700. The log holds no key and no file content. A failed write, or a link or a special file at that path, drops the line.

Code: `src/jev.ts` and `src/second.ts` in the [Claude rig mod](../dot_claude/mods/rig/), and `agent/extensions/lib/jev.ts` and `agent/extensions/gates.ts` in [Pi](../dot_pi/). Check: [J1](MAINTENANCE.md#j1-second-review).

### Project instructions

Pi reads `AGENTS.md` in a project. Claude Code reads `CLAUDE.md` and does not read `AGENTS.md`, so `CLAUDE.md` is a symlink that holds `AGENTS.md`. This repository uses that layout. The `cmd-agents-md` skill converts another repository. A global kernel is not a project file.

### Skills

| Kind        | Home                                                              | Reaches                                                                                                                                                                                                |
| ----------- | ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Personal    | `dot_claude/skills/<name>/`                                       | Claude alone                                                                                                                                                                                           |
| Common      | `dot_agents/skills/<name>/`                                       | Pi reads `~/.agents/skills/` directly. Claude needs a `symlink_<name>` entry                                                                                                                           |
| Third-party | `npx skills add <repo> --skill <name> -g -a claude-code -a pi -y` | An unmanaged copy under `~/.agents/skills/` and an unmanaged link under `~/.claude/skills/`. One line in `docs/skills.tsv`, which lists them for replay                                                |
| App         | The app's setup command, such as `rex skill setup`                | The app writes an unmanaged copy under `~/.agents/skills/`. Replace its copy under `~/.claude/skills/` with an unmanaged link to that copy. To replay, run the setup command, then make the link again |
| Plugin      | Its plugin                                                        | Never linked                                                                                                                                                                                           |

A third-party description is written as if that skill were the only one installed, so the descriptions collide. [SKILLS.md](SKILLS.md) holds the order in which skills compose. The Claude kernel holds the precedence that breaks a tie.

Install a third-party skill with the command above, never by hand. Run `npx skills add <repo> -l` first to read the skill names. Capture one skill directory at a time: a whole-directory add takes the links and the copies with it.

Claude Code frontmatter: `disallowed-tools` removes a tool, and `allowed-tools` is advisory and does not (anthropics/claude-code#37683). A `cmd-*` skill sets `disable-model-invocation: false`. Keep the trigger phrases disjoint across skills. Write a path with forward slashes, never with a backslash. The `whetstone` plugin's `skill-smith` lints the rest.

Pi loads every skill under `~/.agents/skills/`. When two skills have the same name, Pi keeps the first and shows a warning. A Pi-only third-party skill goes to `~/.pi/agent/skills/`; [dot_pi/RIG.md](../dot_pi/RIG.md) holds the loop. `dot_pi/skills.tsv` lists those skills.

### Workspace

Both agents share one workspace in each project: `<repo>/.scratchpad/` of the main checkout when Git ignores it, else `~/.scratchpad/`. A linked worktree uses the workspace of its main checkout. A submodule is its own project. An agent starts at the `START.md` path that `ws` prints.

| Name           | Holds                                                 | Owner                           |
| -------------- | ----------------------------------------------------- | ------------------------------- |
| `START.md`     | Links, open handoffs, open work, idle and loose names | `ws` rebuilds it; no hand edits |
| `INDEX.md`     | Live dossiers                                         | dossier plugin                  |
| `dossier/`     | Dossiers, their archive and `LATER.md`                | dossier plugin                  |
| `OPEN-WORK.md` | The open work register                                | both agents                     |
| `handoff/`     | `<date>-<slug>.md` handoffs                           | both agents                     |
| `tmp/`         | `<date>-<slug>/` scratch output and notes files       | both agents                     |
| `research/`    | Research reports                                      | both agents                     |
| `plans/`       | Claude Code plans, always in the project folder       | Claude Code                     |
| `_archive/`    | Moved files and the `MOVED-<date>.txt` logs           | `ws tidy` and both agents       |

[ws](../exact_dot_bin/executable_ws) writes `START.md` and prints a summary of at most 6 lines. It does not write `INDEX.md` or `dossier/`. `ws tidy` moves each `tmp/` folder whose newest file is 14 or more days old to `_archive/tmp/`, logs each move, and deletes nothing. When the archive already has a name, it leaves that folder and exits 1. The agent that picks up a handoff moves it to `_archive/handoff/`. A name outside the table, except a hidden name, shows in `START.md` as loose.

At session start, both rigs run `ws` and give its summary to the model: the Claude Code rig on each `SessionStart`, and the Pi `workspace` extension on the first run after each session start except `/reload`. When `ws` fails or takes more than 2 seconds, the session starts without the summary.

## Claude Code

| Source                                                                                                  | Owns                                                                         |
| ------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| [dot_claude/.settings.managed.json](../dot_claude/.settings.managed.json)                               | Hook wiring, plugins, MCP declarations, statuslines, settings                |
| [mods/rig](../dot_claude/mods/rig/), [RIG.md](../dot_claude/RIG.md)                                     | Rig mod: hooks, gates, guard, write approval, checks, open items, statusline |
| [dot_claude/CLAUDE.md](../dot_claude/CLAUDE.md), [rules](../dot_claude/rules/)                          | Kernel and path-scoped instructions                                          |
| [agents](../dot_claude/agents/), [skills](../dot_claude/skills/), [workflows](../dot_claude/workflows/) | Delegation contracts and reusable work                                       |
| [dot_cavemem/settings.json](../dot_cavemem/settings.json)                                               | Memory configuration. The database stays unmanaged                           |
| [rtk config.toml](../Library/private_Application%20Support/private_rtk/config.toml)                     | RTK filters and hook exclusions; `git` is excluded                           |

Probe the source and the runtime for model names, plugin revisions, tool inventories, and rule thresholds. A configured key shows intent. The handler and its probe show behavior.

[Skills](#skills) holds the five kinds and the shared store. A common skill reaches Claude through a `symlink_<name>` entry in `dot_claude/skills/` with the content `../../.agents/skills/<name>`. Doctor lint 5e checks the links and the source entries.

### RTK and worktrees

A session starts in the main checkout and works in `wt` worktrees by full path. Reason: after `EnterWorktree`, Claude Code refuses an edit to the main checkout, and dossiers stay there. Branch form: `<type>/<cc|pi>-<first 6 of session ID>-<topic>`. `dot_config/worktrunk/private_config.toml` sets `[merge] remove = false` and excludes `.scratchpad/` from `wt step copy-ignored`. Both guards ask before worktree removal (`mods/rig/src/mutations.ts`, `agent/extensions/guard/core/mutations.ts`).

Native `rtk hook claude` is the only RTK command writer. Keep argv in `rtk proxy`. `git` is excluded from the rewrite because the worktree isolation check refuses a rewritten git command (rtk-ai/rtk#3864).

After `EnterWorktree`, the same check also applies to a `!` command that you type. It refuses `git -C ~/<path>`, because it treats `~` as a runtime value (anthropics/claude-code#88550). It accepts an absolute path and `"$HOME/<path>"`. Rig hooks do not receive `!` commands, so the rig does not cause this refusal and cannot prevent it. When Remote Control is connected, the terminal shows only `detail withheld on this connection`. Start the session with `--debug-file <path>` to read the reason (anthropics/claude-code#99855).

### Plugins, MCP, and memory

First-party plugin source is `~/DEV/rd/claude-code-plugins`. Resolve a deployed file from `installPath` in `~/.claude/plugins/installed_plugins.json`. A cache directory name can be a version, not a SHA. A plugin-registered hook runs outside the rig mod. Disable the plugin in `enabledPlugins` to stop it. Read the manifest and the hook registrations before you enable one.

Three components add hidden context to a prompt: the rig (gate and validator reminders, on `composer` and `bridge` prompts only), cavemem (`user-prompt-submit`), and the dossier plugin (the wave contract line). They do not coordinate and have no cap. The settings do not wire cavemem `session-start`, by design. The worktrunk plugin's `PermissionRequest` hook approves `EnterWorktree` outside the rig guard; this is an accepted gap.

`settings.json.mcpServers` is canonical. [modify_private_dot_claude.json](../modify_private_dot_claude.json) merges that key into `~/.claude.json` and keeps the other state. Probe drift with `chezmoi-claude-doctor.sh` check 4, which compares the `mcpServers` key alone. Do not use `chezmoi diff ~/.claude.json`: Claude Code writes other keys at run time, and a whole-file diff reports a false drift. Probe connectivity with `claude mcp list`. A duplicate server name at two scopes can split OAuth state.

Cavemem keeps its database under `~/.cavemem`. Do not run `cavemem install` over the managed settings. Keep native `autoMemoryEnabled` off, because a native write creates target drift.

- **Install.** After an fnm default change, run `chezmoi-claude-bootstrap.sh --only cavemem`.
- **better-sqlite3 pin.** cavemem 0.2.1 pins `better-sqlite3@^11`, which aborts in the Node garbage collector ([WiseLibs/better-sqlite3#1515](https://github.com/WiseLibs/better-sqlite3/issues/1515)). The bootstrap installs cavemem with `--ignore-scripts`, then installs the pinned 12.x under cavemem. After a manual `npm i -g cavemem`, run `--only cavemem`.
- **Install scripts.** Keep the temporary `.npmrc` of `cavemem_pin_bsql` as the only install-script permission for better-sqlite3.
- **Ranker patch.** cavemem 0.2.1 search overflows the stack on a large store. `cavemem-health.sh` reports it as `rank`, and the bootstrap patches the ranker ([JuliusBrussee/cavemem#62](https://github.com/JuliusBrussee/cavemem/pull/62)). Remove the patch when a release has the fix. An MCP server keeps the old code until it restarts.

## Pi

`dot_pi/` owns the Pi kernel (`agent/AGENTS.md` and `agent/APPEND_SYSTEM.md`), the extensions, the agents, the rules, the themes, and the skill list. Read [RIG.md](../dot_pi/RIG.md) for behavior and limits.

[.chezmoiignore](../.chezmoiignore) uses an allow list for `.pi`. A new managed path needs an entry in that list. Keep authentication, sessions, `models-store.json`, `mcp-auth.json`, and package installs unmanaged. The modify script `agent/modify_settings.json` writes `settings.json`, and the template `agent/mcp.json.tmpl` writes `mcp.json`. `re-add` skips both.

## Operator tools

| Tool                                   | Purpose                                                                                                                                                                                                                                                                                                                                                                                                       |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `chezmoi-claude-doctor.sh`             | Diagnoses configuration and drift. `--rewake` writes warnings to `~/.claude/markers/doctor-warnings.txt` and skips a background session. On a new Claude Code version it re-tests the rig mod and logs to `~/.claude/markers/rig-gate.log`. It warns when the Codex daemon or Pi keeps more than two releases, and on a link in `~/.bin` or `~/.claude/skills` to a missing file. See [M1](MAINTENANCE.md#m1) |
| `chezmoi-claude-bootstrap.sh`          | Installs runtime prerequisites. `--check`, `--only`, `--skip`                                                                                                                                                                                                                                                                                                                                                 |
| `cavemem-health.sh`                    | Prints the cavemem problems for the doctor, the bootstrap and `cavemem-repair`. Exit 1 when it finds one                                                                                                                                                                                                                                                                                                      |
| `claude-flag-audit.sh [days] [-v]`     | Lists safeguard `model_refusal_fallback` events in the Claude transcripts. The doctor calls it                                                                                                                                                                                                                                                                                                                |
| `chezmoi-fixture-check.sh`             | Runs the S3 deployment fixture checks                                                                                                                                                                                                                                                                                                                                                                         |
| `dotfiles-privatize.sh <dir> [--push]` | Moves a source directory to the private repo as branch `<dir>`. Without `--push` it prints the remaining commands                                                                                                                                                                                                                                                                                             |
| `pkill`, `pgrep`                       | Refuses an option that follows the pattern. BSD getopt stops at the first pattern                                                                                                                                                                                                                                                                                                                             |
| `lens-review`                          | Workflow in `dot_claude/workflows/`, registered through `meta.name`. Reviews a source change                                                                                                                                                                                                                                                                                                                  |

The doctor's agent additions check warns about each item in Claude, Pi or Codex that the source and [agent-additions.txt](agent-additions.txt) do not hold. It runs at each new Claude Code session start, also outside this repository, and the statusline shows the warning count. It does not block an item and detects it after the write. It does not read project files, the content of a hook, the content of an installed third-party skill, or a Codex TOML dotted key. It matches a Pi, a Codex or a project MCP server by name alone. An edit to the approved list shows in `git status`, not as a warning.
