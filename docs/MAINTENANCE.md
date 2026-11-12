# Maintenance checks

Diagnose only. Do not apply, repair, update, or commit during a check. Run each applicable probe. Compare the result with the pass criterion. Report each failure and each skipped check in one line. An agent whose rig denies a step marked "operator runs" skips it and reports it as skipped.

## Choose checks for your change

| Change                                         | Checks                                                                  |
| ---------------------------------------------- | ----------------------------------------------------------------------- |
| Documentation                                  | Local links, code blocks, preserved constraints, and `git diff --check` |
| Shared deployment or Git hooks                 | S1 to S3 below; M15 and M16 fixture checks                              |
| Pi rig                                         | P1 below                                                                |
| Claude rig mod or hook rules                   | M1, M4, S1, and S2                                                      |
| Claude validator or formatter registry         | M4                                                                      |
| Claude plugin                                  | M1 to M3                                                                |
| Shell, terminal, editor, or desktop            | Applicable terminal probes below and the component's own checks         |
| Rex config, helpers, or app settings           | R1 below                                                                |
| Workspace command `ws`                         | W1 below                                                                |
| Jev question file or second-review gate        | J1 below                                                                |
| Rig metrics `rig-metrics`                      | G1 below                                                                |
| `signoff` agent prompt                         | G2 below                                                                |
| Pane monitor skill `cmd-monitor-pane`          | `bun test ./tests/monitor-pane` (about 1 minute), then R1               |
| `install.sh`, `.chezmoiignore`, or an external | X1 below                                                                |

Use disposable fixtures for checks that write files or send keys. Do not run them against the operator's live windows or sessions.

## Shared deployment

### S1: Source and target drift

Run `chezmoi status`. Run `chezmoi diff <target>` for each named path that is not private. A private path can hold a secret, so report its status line only. The rig blocks a bare `chezmoi diff` and a diff of a private target. Do not apply. Report the drifted paths. Pass: an empty status.

### S2: Private submodules

Run `git submodule status`. Read the `core.hooksPath` of each submodule and expect `.githooks`. A leading `+` means that the checkout differs from the recorded commit. It does not show ahead, behind, or divergence. Inspect the ancestry before you propose a repair. A leading `-` means that the submodule is not initialized.

Expect `push.recurseSubmodules` `on-demand`, `submodule.recurse` `false`, and `status.submoduleSummary` `true`. Expect `merge` for the update setting of each managed submodule.

### S3: Deployment boundary

Run `~/.bin/chezmoi-fixture-check.sh`. It applies a synthetic source to an isolated destination and state file. Expected: exit 0.

### X1: Linux sandbox

Commit the change first. The check clones the branch `b`. For a branch in a worktree, set `w` to the worktree path, so the check script comes from that branch.

```sh
b=main w=~/.dotfiles
docker run --rm -v ~/.dotfiles:/src:ro -v "$w/tests/sandbox:/probe:ro" \
  -e CODESPACES=true ubuntu:24.04 bash /probe/check.sh "$b"
```

Expected: `0 failed`. The check runs `install.sh` from a fresh clone, as Codespaces does, then checks that the shell, git, editor and tmux files exist, that no macOS, secret or agent target exists, that a commit and a tag work unsigned, that `install.sh` from a pipe stops, that zsh starts, and that a second apply changes nothing. A missing `unzip` line from zsh is expected in the bare image

## Pi

### P1: Submodule and deployment boundary

- `git -C ~/.dotfiles/dot_pi status -sb`: expect the `dot_pi` branch.
- `chezmoi status ~/.pi`: expect no line with a letter in column two. `M` in column one alone is expected for `settings.json`. Then run `chezmoi diff --recursive ~/.pi`.
- Operator runs: `pi --version`: expect the `@earendil-works/pi-coding-agent` version in `dot_pi/package.json`.
- `ls ~/.local/share/fnm/node-versions/*/installation/bin/pi`: expect no match.
- Operator runs: `cd /tmp && pi -p --no-session "Reply with ok." < /dev/null`: expect `ok`.
- Operator runs: start `pi` once: expect no error or warning above the editor.
- `cd ~/.dotfiles/dot_pi && npm test`: expect exit 0.
- Operator runs: `pi mcp list`: expect 5 connected servers.
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

After a change to the switcher, also run `cd ~/.dotfiles && bun test ./tests/switcher`. Expected: All tests pass. Report the count

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

## Rex

### R1

`rex config check ~/.dotfiles/dot_config/rex/init.lua --json`; `tests/rex/sandbox.sh`; `tests/rex/gate.sh`; `shellcheck dot_config/rex/bin/executable_rex-{agent-record,ask,fzf,open,popup,reader,urls} tests/rex/*.sh tests/rex/cases/*.sh`

Expected: No diagnostics; both test scripts end with `all passed`; shellcheck exits 0

In a worktree with no `dot_claude` submodule, run `sandbox.sh` with `SANDBOX_DOT_CLAUDE=~/.dotfiles/dot_claude`.

R1 also covers `run_onchange_after_rex-defaults.sh.tmpl`, `run_onchange_before_rex-config-check.sh.tmpl` and `dot_config/rex/themes/`.

## Workspace

### W1

`cd ~/.dotfiles && bun test tests/ws`

Expected: All tests pass. Report the count. A change to the session-start summary also runs M4 and P1

## Second review

### J1: Second review

`cd ~/.dotfiles && bun test ./tests/jev`; `cd ~/.dotfiles/dot_claude/mods/rig && bun build.ts && claude plugin test dist`; `cd ~/.dotfiles/dot_pi && bun test test/jev.test.ts test/gates.test.ts`; `chezmoi status ~/.agents/jev`

Expected: All three runs pass; report the counts. `chezmoi status` prints nothing. Use `./tests/jev` (a bare `tests/jev` is a name filter and also matches the rig's `jev.test.ts`). Run the Pi tests by file name: `test/rtk-native.test.ts` fails in the full suite. See [ARCHI.md](ARCHI.md#second-review)

### G1: Rig metrics

`cd ~/.dotfiles && bun test ./tests/rig-metrics`; `rig-metrics triggers >/dev/null`

Expected: All tests pass; report the count. `rig-metrics triggers` exits 0. See [ARCHI.md](ARCHI.md#rig-metrics)

### G2: Signoff agent

`cd ~/.dotfiles/tests/signoff-eval && rm -rf agents && mkdir agents && cp ../../dot_claude/agents/signoff.md ../../dot_claude/agents/evidence.md agents/ && claude plugin eval . --no-publish --runs 2 --ablation none --trust-plugin --allow-tools Bash Write Read Agent`

Expected: Exit 0. In every run, the driver spawns `signoff-eval:evidence`, and the reply of case `sound-design` is `SIGNOFF: PASS` and the reply of case `check-passes-today` is `SIGNOFF: CHANGES`. The two designs differ only in the first invariant: in `check-passes-today`, its check passes on the current code. The suite shows that the agent returns `SIGNOFF: CHANGES` for a design whose only difference is such a check, not why. The graders read only the driver's spawn and last line; to confirm that the evidence agent spawned `signoff-eval:signoff`, add `--keep-temp` and read `out/trace.jsonl`. The suite has no dossier case, so it does not cover the `ds design-check` step. Needs the private `dot_claude` submodule; without it, `cp` fails. The plugin loader does not follow a symlinked agent file, so the check copies the agent; `agents/` and `evals/results/` are gitignored. Keep `--no-publish`: without it, the report goes to claude.ai. Four runs cost about $1; the evidence agent runs on Haiku, the signoff agent on Fable and the driver on the default model.

## Claude Code

### M1

`~/.bin/chezmoi-claude-doctor`

Expected: Exit 0. No `WARN:`, `ORPHAN:`, or `LINT:` line

After a change to the doctor, also run `cd ~/.dotfiles && bun test ./tests/doctor`. Expected: All tests pass. Report the count

A `WARN: agent addition:` line names an item that you did not approve. Remove the item, or add its `<kind> <name>` line to [agent-additions.txt](agent-additions.txt).

### M2

`claude plugin list`; read doctor check `[warn 1/8]`, which compares each first-party `gitCommitSha` with `origin/main` of `~/DEV/rd/claude-code-plugins`

Expected: The expected plugins are enabled. First-party revisions agree, or you report the gap

### M3

`claude mcp list`

Expected: Configured servers connect. No scope conflict

### M4

`cd ~/.dotfiles/dot_claude/mods/rig && bun build.ts && claude plugin test dist`

Expected: `build.ts` exits 0, so the source type-checks against the host types. All tests pass. Report the count

The parity corpus reads recorded `shfmt` trees from `tests/shfmt-corpus-trees*.ts`. After a change to the corpus, to the rig's shell reader, or to `shfmt`, record them again and check for drift:

`cd ~/.dotfiles/dot_claude/mods/rig && bun record-shfmt.ts && git status --porcelain -- 'tests/shfmt-corpus-trees*'`

Expected: `record-shfmt: <N> trees in <P> passes`, then no output from `git status`. Output from `git status` means the trees changed: run M4 again, and commit the new trees only when the suite passes

### M6

`rtk hook check 'ls -la'`; `rtk hook check 'git status'`; `rtk gain`

Expected: `rtk ls -la`, then `No rewrite for: git status` (`git` is excluded), then a savings report

### M7

`command -v actionlint shellcheck hadolint ruff go staticcheck gofmt shfmt mdformat`

Expected: All resolve

### M8

Inspect `~/.claude/markers`

Expected: No file directly in `~/.claude/markers` older than one day. The rig deletes them at each session end

### M9

`~/.bin/cavemem-health.sh`; read `lastError` in `~/.cavemem/worker.state.json`

Expected: Exit 0 (M1 also runs it). `lastError` is null. MCP connects (M3)

### M10

Update the shared skills by name: `npx skills update -g -y $(cut -f2 ~/.dotfiles/docs/skills.tsv)`. Pi-only skills update through the loop in `dot_pi/RIG.md`. Compare `npx skills list -g` with `docs/skills.tsv` (one `source<TAB>name` line per third-party skill, added by hand at install). Replay a missing skill with the loop below. Run `/skill-doctor` in a session

```bash
while IFS=$'\t' read -r src name; do npx skills add "$src" --skill "$name" -g -a claude-code -a pi -y; done < ~/.dotfiles/docs/skills.tsv
```

Expected: Each skill is personal, common, third-party, app, or plugin. `npx skills list -g` equals the manifest. No never-invoked skill that you want to keep. Unused plugins reviewed

### M11

Search each `exact_dot_bin/` script and `dot_claude/workflows/*.js` name across the rig and this documentation

Expected: Each has a consumer, or appears in [Operator tools](ARCHI.md#operator-tools) or the workflow registry

### M12

The claim checker. It needs the optional whetstone Claude plugin and is separate from the documentation checks.

```sh
bash "$(jq -r '.plugins["whetstone@raisedadead-plugins"][0].installPath' ~/.claude/plugins/installed_plugins.json)/bin/claim-check" AGENTS.md docs/README.md docs/ARCHI.md docs/MAINTENANCE.md
```

Expected: Exit 0 and `CLAIMS: CLEAN`

### M15

In a throwaway super/sub pair with both hooks on `core.hooksPath`: commit in the sub, then `commit --amend`, then `commit --amend --date=2001-02-03`

Expected: The super tip reads `chore(sub): bump to <sha>`. After each amend the super has one bump commit with the new sha, the super author, and the super date

### M16

Feed `.githooks/pre-push` a stdin ref line whose sha records a pushed submodule commit, then one whose gitlink is on no submodule remote

Expected: Exit 0, then exit 1 with the submodule, the gitlink, and the push command
