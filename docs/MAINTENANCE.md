# Maintenance checks

Diagnose only. Do not apply, repair, update, or commit during a check. Run each applicable probe. Compare the result with the pass criterion. Report each failure and each skipped check in one line.

## Choose checks for your change

| Change                                 | Checks                                                                  |
| -------------------------------------- | ----------------------------------------------------------------------- |
| Documentation                          | Local links, code blocks, preserved constraints, and `git diff --check` |
| Shared deployment or Git hooks         | S1 and S2 below; M15 and M16 fixture checks                             |
| Codex rig                              | C1 to C4 below                                                          |
| Claude dispatcher or hook rules        | M1 and M4                                                               |
| Claude validator or formatter registry | Spec smoke test                                                         |
| Claude plugin                          | M1 to M3                                                                |
| Shell, terminal, editor, or desktop    | Applicable terminal probes below and the component's own checks         |

Use disposable fixtures for checks that write files or send keys. Do not exercise them against the operator's live windows or sessions.

## Shared deployment

### S1: Source and target drift

Run `chezmoi status`. Read named diffs without applying. Report drifted paths; do not print secret values. An empty status is the pass criterion.

### S2: Private submodules

Run `git submodule status` and inspect each submodule's `core.hooksPath`. Expect `.githooks`. A leading `+` means the checkout differs from the recorded commit; it does not establish ahead, behind, or divergence. Inspect ancestry before proposing a repair. A leading `-` means the submodule is not initialized.

Check `push.recurseSubmodules`, `submodule.recurse`, and `status.submoduleSummary`: expect `on-demand`, `false`, and `true`. Expect `merge` for each managed submodule's update setting.

## Codex

### C1: Hook behavior and style

```sh
PYTHONDONTWRITEBYTECODE=1 /opt/homebrew/bin/python3 ~/.dotfiles/dot_codex/hooks/test_codex_hooks.py
ruff check --no-cache ~/.dotfiles/dot_codex/hooks
ruff format --check --no-cache ~/.dotfiles/dot_codex/hooks
```

Expect the suite and style checks to pass. Report failures and skipped tools.

### C2: Native command rules

```sh
codex execpolicy check --rules ~/.dotfiles/dot_codex/rules/safety.rules -- git push
```

Expect `forbidden`. This checks a command vector; it does not execute a push.

### C3: Installation health

Run `codex doctor --summary`. Report its failures separately from hook results. Do not repair during this check.

### C4: Deployment boundary and live behavior

Render and apply the selected rig files to an isolated destination and state file. Verify that unmanaged state survives and owner documents are absent. Compare installed named files with source. After approved activation, test an allowed patch, a blocked disposable private path, invalid JSON, and corrected JSON in a disposable directory. Record the client and tool path tested.

## Terminal stack

### T1

`ghostty +validate-config`; `ghostty +show-config`

Expected: No configuration error. Shell integration keeps `path`

### T2

`(for f in ~/.zshenv ~/.config/zsh/.zshenv ~/.config/zsh/.zprofile ~/.config/zsh/.zshrc ~/.config/zsh/*.zsh; do zsh -n "$f" || exit; done)`

Expected: Exit 0

### T3

`whence -p node brew zsh` and `print -l $path` in bare, interactive, login, and `env -i` zsh

Expected: fnm node and Homebrew come before the system copies. User commands come first

### T4

`zsh -ic 'print -l $fpath'`; compare `bindkey` before and after a startup change

Expected: No duplicate in fpath. Ctrl+R is Atuin, Ctrl+T is the file widget, Ctrl+F is mdr

### T5

In a new shell: `chezmoi re-add ~/.config/zsh/<Tab>`; select, then cancel the line

Expected: The picker includes dotfiles. A selection completes a target path

### T6

Ctrl+T on an empty argument, on `~/.config/zsh/fz`, on a quoted path with spaces, and on a word before another argument; repeat with Escape

Expected: Root and query follow the argument. A selection replaces it. Other text and cancel stay intact

### T7

Ctrl+T in a temporary Git fixture with hidden, ignored, directory, and binary entries; press `<C-g>`

Expected: Default respects ignores. `<C-g>` shows ignored paths. Previews fit the entry type

### T8

Compare each `plugins.lock` revision with `git -C "$ZPLUGDIR/<repo-name>" rev-parse HEAD`

Expected: Recorded and installed revisions agree

### T9

`shellcheck` on changed tmux Bash scripts; parse and load the tmux config on an isolated socket

Expected: No new diagnostic. No effect on a live session

### T10

`tmux list-clients -F '#{client_termname}: #{client_termfeatures}'`; `tmux show -g extended-keys`; read the root bindings

Expected: Client features and Alt+Shift routing agree with [ARCHI.md](ARCHI.md#terminal-stack)

### T11

`M-H/J/K/L` across shell panes and Neovim splits; Ctrl+Shift+W/E/A/S in shell and editor; copy text

Expected: The correct consumer gets each key. The clipboard works. Shell Ctrl+Shift+W deletes to line start

### T12

Switcher: a file deeper than four directories, a text match after line 5,000, a query change, a Files/Grep switch, a bookmark

Expected: Deep and late matches appear. The query reloads. Files mode restores fuzzy search. The bookmark marker stays visible

### T13

`nvim --headless '+checkhealth' +qa`; compare lazy-lock entries with installed plugin heads

Expected: No provider or tool failure. Lock and installed revisions agree

### T14

Save Markdown with two trailing spaces and Lua with trailing spaces; repeat Lua with autoformat off; open a source buffer

Expected: The Markdown hard break stays. Enabled Lua trim runs. Disabled trim does not. No implicit chezmoi apply

### T15

Repeated `/usr/bin/time -p zsh -ic exit`; `ZPROF=true zsh -ic exit` for attribution

Expected: Medians match the same-machine baseline

### T16

Shader on and off with equal window size, display, text, focus, and scroll workload

Expected: CPU and GPU or energy recorded separately

Give every tmux probe a unique `-L` or `-S`, including cleanup. `-f /dev/null` selects a config, not a server. `TMUX_TMPDIR` does not override an inherited `$TMUX`. Read the parse output; tmux can exit 0 with an error in it. Use disposable fixtures for write and key-routing checks. A completion test must not run the completed command.

## Claude Code

### M1

`~/.bin/chezmoi-claude-doctor.sh`

Expected: Exit 0. No `WARN:`, `ORPHAN:`, or `LINT:` line

### M2

`claude plugin list`; compare `gitCommitSha` with `git -C ~/DEV/rd/claude-code-plugins rev-parse HEAD`

Expected: Expected plugins enabled. First-party revisions agree, or the gap is reported

### M3

`claude mcp list`

Expected: Configured servers connect. No scope conflict

### M4

`~/.bin/chezmoi-claude-hooks-test.sh --all`

Expected: Both suites pass. Report each count

### M5

`chezmoi diff`

Expected: Empty, or the drifted paths listed without an apply

### M6

`rtk hook check 'git status'`; `rtk gain`

Expected: `rtk git status`, then a savings report

### M7

`command -v actionlint shellcheck hadolint ruff go staticcheck gofmt shfmt mdformat`

Expected: All resolve

### M8

Inspect `~/.claude/markers`

Expected: Fewer than 400 files. No non-exempt file older than two days

### M9

Inspect the Cavemem worker state and M3

Expected: `lastError` is null. MCP connects

### M10

Compare deployed skill directories and symlinks with source `cmd-*` and plugin registrations. Run `/skill-doctor` in a session

Expected: Each skill has an owner. No broken symlink. No never-invoked skill that you want to keep. Unused plugins reviewed

### M11

Search each `exact_dot_bin/` script and `dot_claude/workflows/*.js` name across the rig and this documentation

Expected: Each has a consumer, or appears in [Operator tools](ARCHI.md#operator-tools) or the workflow registry

### M12

The claim checker below

Expected: Exit 0 and `CLAIMS: CLEAN`

### M13

Shared submodule check S2

Expected: Report the Claude checkout and hook path

### M14

Shared Git configuration check S2

Expected: Report the effective values

### M15

In a throwaway super/sub pair with both hooks on `core.hooksPath`: commit in the sub, then `commit --amend`, then `commit --amend --date=2001-02-03`

Expected: The super tip reads `chore(sub): bump to <sha>`. After each amend the super has one bump commit with the new sha, the super author, and the super date

### M16

Feed `.githooks/pre-push` a stdin ref line whose sha records a pushed submodule commit, then one whose gitlink is on no submodule remote

Expected: Exit 0, then exit 1 with the submodule, the gitlink, and the push command

This optional Claude plugin check is separate from general documentation validation.

```sh
bash "$(jq -r '.plugins["whetstone@raisedadead-plugins"][0].installPath' ~/.claude/plugins/installed_plugins.json)/bin/claim-check" AGENTS.md docs/README.md docs/ARCHI.md docs/MAINTENANCE.md
```

A dispatcher or hook-rule edit needs M4. A validator or formatter registry edit needs the spec smoke test. A plugin upgrade needs M1 to M3. A shell, Ghostty, tmux, or Neovim change needs the terminal checks. The doctor does not replace them.
