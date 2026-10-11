# Maintenance checks

Diagnose only. Do not apply, repair, update, or commit during a check. Run each applicable probe. Compare the result with the pass criterion. Report each failure and each skipped check in one line.

## Choose checks for your change

| Change                                 | Checks                                                                  |
| -------------------------------------- | ----------------------------------------------------------------------- |
| Documentation                          | Local links, code blocks, preserved constraints, and `git diff --check` |
| Shared deployment or Git hooks         | S1, S2, and C4 below; M15 and M16 fixture checks                        |
| Codex rig                              | C1 to C4 below                                                          |
| Pi rig                                 | P1 below                                                                |
| Claude rig mod or hook rules           | M1 and M4                                                               |
| Claude validator or formatter registry | Spec smoke test                                                         |
| Claude plugin                          | M1 to M3                                                                |
| Shell, terminal, editor, or desktop    | Applicable terminal probes below and the component's own checks         |

Use disposable fixtures for checks that write files or send keys. Do not run them against the operator's live windows or sessions.

## Shared deployment

### S1: Source and target drift

Run `chezmoi status`. Read each named diff. Do not apply. Report the drifted paths. Do not print secret values. Pass: an empty status.

### S2: Private submodules

Run `git submodule status`. Read the `core.hooksPath` of each submodule and expect `.githooks`. A leading `+` means that the checkout differs from the recorded commit. It does not show ahead, behind, or divergence. Inspect the ancestry before you propose a repair. A leading `-` means that the submodule is not initialized.

Expect `push.recurseSubmodules` `on-demand`, `submodule.recurse` `false`, and `status.submoduleSummary` `true`. Expect `merge` for the update setting of each managed submodule.

## Codex

### C1: Hook behavior and style

```sh
PYTHONDONTWRITEBYTECODE=1 /opt/homebrew/bin/python3 ~/.dotfiles/dot_codex/hooks/test_codex_hooks.py
ruff check --no-cache ~/.dotfiles/dot_codex/hooks
ruff format --check --no-cache ~/.dotfiles/dot_codex/hooks
```

Expect the suite and the style checks to pass. Report failures and skipped tools.

### C2: Native command rules

```sh
codex execpolicy check --rules ~/.dotfiles/dot_codex/rules/safety.rules -- git push
```

Expect `forbidden`. The check reads a command vector. It does not run a push.

### C3: Installation health

Run `codex doctor --summary`. Report its failures separately from the hook results.

### C4: Deployment boundary and live behavior

Run `~/.bin/chezmoi-fixture-check.sh`. It applies a synthetic source to an isolated destination and state file. It checks six boundaries: rendered paths and permissions, an unchanged second apply, survival outside an exact directory, removal inside one, an absent excluded document, and what a named capture takes from its siblings.

Then render and apply the selected rig files to an isolated destination and state file. Verify that unmanaged state survives and that owner documents are absent. Compare the installed named files with the source. After approved activation, test an allowed patch, a blocked disposable private path, invalid JSON, and corrected JSON in a disposable directory. Record the client and the tool path that you tested.

## Pi

### P1: Submodule and deployment boundary

- `git -C ~/.dotfiles/dot_pi status -sb`: expect the `dot_pi` branch.
- `chezmoi status ~/.pi`: expect no line with a letter in column two. Pi rewrites `settings.json` at run time, so `M` in column one alone is expected there. A `chezmoi diff` of a directory does not recurse without `--recursive` (chezmoi 2.73.0), so read the status, then run `chezmoi diff --recursive ~/.pi`.
- `pi --version`: expect the `@earendil-works/pi-coding-agent` version in `dot_pi/package.json`.
- `ls ~/.local/share/fnm/node-versions/*/installation/bin/pi`: expect no match.
- `cd /tmp && pi -p --no-session "Reply with ok." < /dev/null`: expect `ok`.
- Start `pi` once: expect no error or warning above the editor.
- `cd ~/.dotfiles/dot_pi && npm test`: expect exit 0.
- `pi mcp list`: expect 6 connected servers.
- `ls ~/.pi/agent/skills`: expect the names in `dot_pi/skills.tsv`.

## Terminal stack

Rules for tmux probes:

- Give each tmux probe a unique `-L` or `-S`. Use the same flag for cleanup.
- `-f /dev/null` selects a config, not a server.
- `TMUX_TMPDIR` does not override an inherited `$TMUX`.
- Read the parse output. tmux can exit 0 with an error in it.
- Do not run the completed command in a completion test.

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

## Claude Code

### M1

`~/.bin/chezmoi-claude-doctor.sh`

Expected: Exit 0. No `WARN:`, `ORPHAN:`, or `LINT:` line

### M2

`claude plugin list`; read doctor check `[warn 1/4]`, which compares each first-party `gitCommitSha` with `origin/main` of `~/DEV/rd/claude-code-plugins`

Expected: The expected plugins are enabled. First-party revisions agree, or you report the gap

### M3

`claude mcp list`

Expected: Configured servers connect. No scope conflict

### M4

`cd ~/.dotfiles/dot_claude/mods/rig && ./build.sh && claude plugin test dist`

Expected: All tests pass. Report the count

### M5

`chezmoi diff`

Expected: Empty. Otherwise, list the drifted paths. Do not apply

### M6

`rtk hook check 'ls -la'`; `rtk hook check 'git status'`; `rtk gain`

Expected: `rtk ls -la`, then `No rewrite for: git status` (`git` is excluded), then a savings report

### M7

`command -v actionlint shellcheck hadolint ruff go staticcheck gofmt shfmt mdformat`

Expected: All resolve

### M8

Inspect `~/.claude/markers`

Expected: Fewer than 400 files. No non-exempt file older than two days

### M9

Inspect the Cavemem worker state and M3. Read the `better-sqlite3` version under `~/.local/share/fnm/aliases/default/lib/node_modules/cavemem/node_modules`

Expected: `lastError` is null. MCP connects. The `better-sqlite3` major is 12 or higher

### M10

Run `npx skills check -g`. Review the reported changes, then run `npx skills update -g -y`. Compare `npx skills list -g` with `docs/skills.tsv`. The manifest has one `source<TAB>name` line for each third-party skill. Add the line by hand at each install. Replay a missing skill with the loop below. Run `find ~/.claude/skills -maxdepth 1 -type l ! -lname '../../.agents/skills/*'`. Run `/skill-doctor` in a session

```bash
while IFS=$'\t' read -r src name; do npx skills add "$src" --skill "$name" -g -a claude-code -a codex -y; done < ~/.dotfiles/docs/skills.tsv
```

Expected: Each skill is personal, common, third-party, or plugin. The find prints nothing. `npx skills list -g` equals the manifest. No never-invoked skill that you want to keep. Unused plugins reviewed

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

M12 needs the optional whetstone Claude plugin. It is separate from the documentation checks.

```sh
bash "$(jq -r '.plugins["whetstone@raisedadead-plugins"][0].installPath' ~/.claude/plugins/installed_plugins.json)/bin/claim-check" AGENTS.md docs/README.md docs/ARCHI.md docs/MAINTENANCE.md
```

The doctor (M1) does not replace the checks in [Choose checks for your change](#choose-checks-for-your-change).
