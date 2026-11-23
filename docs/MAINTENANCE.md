# Maintenance checks

This page lists the checks to run after a change to the Claude Code rig or the shared configuration.

Diagnose only. Do not apply, repair, update or commit during a check. Report each failure in one line. Use disposable fixtures for a check that writes files or sends keys.

## Choose checks for your change

| Change                                         | Checks                                                                  |
| ---------------------------------------------- | ----------------------------------------------------------------------- |
| Documentation                                  | Local links, code blocks, preserved constraints, and `git diff --check` |
| Shared deployment or Git hooks                 | S1 to S3; M15 and M16                                                   |
| Claude rig mod or hook rules                   | M1, M4, S1, S2                                                          |
| Claude validator or formatter registry         | M4                                                                      |
| Claude plugin                                  | M1 to M3                                                                |
| Shell, terminal, editor, or desktop            | T1 to T13 that apply                                                    |
| Rex config, helpers, or app settings           | R1                                                                      |
| Rig metrics `rig-metrics`                      | G1                                                                      |
| Pane watch skill `cmd-watch-pane`              | `bun test ./tests/monitor-pane`, then R1                                |
| `install.sh`, `.chezmoiignore`, or an external | X1                                                                      |

## Shared deployment

### S1: Source and target drift

```sh
chezmoi status
```

Run `chezmoi diff <target>` for each named path that is not private. For a private path, report the status line only.

Expected: An empty status.

### S2: Private submodules

```sh
git submodule status
```

Expected: No leading `+` or `-`. `core.hooksPath` of each submodule is `.githooks`. `push.recurseSubmodules` is `on-demand`, `submodule.recurse` is `false`, `status.submoduleSummary` is `true`, and the update setting of each managed submodule is `merge`.

### S3: Deployment boundary

```sh
~/.bin/chezmoi-fixture-check.sh
```

Expected: Exit 0.

### X1: Linux sandbox

Commit the change first. Set `b` to the branch. For a branch in a worktree, set `w` to the worktree path.

```sh
b=main w=~/.dotfiles
docker run --rm -v ~/.dotfiles:/src:ro -v "$w/tests/sandbox:/probe:ro" \
  -e CODESPACES=true ubuntu:24.04 bash /probe/check.sh "$b"
```

Expected: `0 failed`.

## Terminal stack

Give each tmux probe a unique `-L` or `-S`. Read the parse output: tmux can exit 0 with an error in it.

### T1

```sh
ghostty +validate-config
```

Expected: No configuration error.

### T2

```sh
for f in ~/.zshenv ~/.config/zsh/.zshenv ~/.config/zsh/.zprofile ~/.config/zsh/.zshrc ~/.config/zsh/*.zsh; do zsh -n "$f" || exit; done
```

Expected: Exit 0.

### T3

```sh
whence -p node brew zsh
```

Run it in bare, interactive, login and `env -i` zsh.

Expected: fnm node and Homebrew come before the system copies.

### T4

```sh
zsh -ic 'print -l $fpath'
```

Expected: No duplicate in fpath. Ctrl+R is Atuin, Ctrl+T is the file widget, Ctrl+F is mdr.

### T5

In a new shell, type `chezmoi re-add ~/.config/zsh/<Tab>`. Press Ctrl+T in a temporary Git fixture with hidden, ignored and binary entries. Press `<C-g>`.

Expected: The picker lists dotfiles. The default view respects ignores. `<C-g>` shows ignored paths.

### T6

```sh
git -C "$ZPLUGDIR/<repo-name>" rev-parse HEAD
```

Expected: The result matches the `plugins.lock` revision.

### T7

```sh
shellcheck <changed tmux Bash scripts>
```

Expected: No new diagnostic.

### T8

```sh
tmux list-clients -F '#{client_termname}: #{client_termfeatures}'; tmux show -g extended-keys
```

Expected: Client features and Alt+Shift routing agree with [ARCHI.md](ARCHI.md#terminal-stack).

### T9

Press `M-H/J/K/L` across shell panes and Neovim splits. Press Ctrl+Shift+W/E/A/S in shell and editor.

Expected: The correct consumer gets each key. Shell Ctrl+Shift+W deletes to line start.

### T10

After a change to the switcher, run:

```sh
cd ~/.dotfiles && bun test ./tests/switcher
```

Expected: All tests pass.

### T11

```sh
nvim --headless '+checkhealth' +qa
```

Expected: No failure in an enabled editor integration. Health can report missing tools for disabled Snacks modules and unused providers. Each `nvim-pack-lock.json` revision matches the corresponding installed package.

### T12

Save Markdown with two trailing spaces and Lua with trailing spaces.

Expected: The Markdown hard break stays. Lua trailing spaces are trimmed.

### T13

```sh
/usr/bin/time -p zsh -ic exit
```

Expected: The median matches the same-machine baseline.

## Rex

### R1

```sh
rex config check ~/.dotfiles/dot_config/rex/init.lua --json
tests/rex/sandbox.sh
tests/rex/gate.sh
shellcheck dot_config/rex/bin/executable_rex-{agent-record,ask,fzf,open,popup,reader,urls} tests/rex/*.sh tests/rex/cases/*.sh
```

In a worktree with no `dot_claude` submodule, run `sandbox.sh` with `SANDBOX_DOT_CLAUDE=~/.dotfiles/dot_claude`.

Expected: No diagnostics. Both test scripts end with `all passed`. shellcheck exits 0.

## Rig metrics

### G1: Rig metrics

```sh
cd ~/.dotfiles && bun test ./tests/rig-metrics && rig-metrics 7 >/dev/null
```

Expected: Exit 0.

## Claude Code

### M1

```sh
~/.bin/chezmoi-claude-doctor
```

After a change to the doctor, run `cd ~/.dotfiles && bun test ./tests/doctor`. For a `WARN: agent addition:` line, remove the item or add its `<kind> <name>` line to [agent-additions.txt](agent-additions.txt).

Expected: Exit 0. No `WARN:`, `ORPHAN:` or `LINT:` line.

### M2

```sh
claude plugin list
```

Expected: The expected plugins are enabled. Doctor check `[warn 1/6]` shows no first-party drift.

### M3

```sh
claude mcp list
```

Expected: Configured servers connect. No scope conflict.

### M4

```sh
cd ~/.dotfiles/dot_claude/mods/rig && bun build.ts && claude plugin test dist && claude plugin validate dist && bun check-launcher.ts
```

After a change to the parity corpus, the rig shell reader or `shfmt`, run:

```sh
cd ~/.dotfiles/dot_claude/mods/rig && bun record-shfmt.ts && git status --porcelain -- 'tests/shfmt-corpus-trees*'
```

Expected: Exit 0. All tests pass, then `Validation passed`, then `LAUNCHER: OK 3 rows` for the source of the RTK hook. `record-shfmt: <N> trees in <P> passes`, then no `git status` output. If `git status` prints a line, run M4 again. Commit the new trees only when the suite passes.

### M6

```sh
rtk hook check 'ls -la'; rtk hook check 'git status'
```

Expected: `rtk ls -la`, then `No rewrite for: git status`.

The hook `~/.claude/hooks/rtk-rewrite` writes nothing in the permission mode `auto`:

```sh
bun ~/.dotfiles/dot_claude/mods/rig/check-launcher.ts ~/.claude/hooks/rtk-rewrite
```

Expected: `LAUNCHER: OK 3 rows`. A `FAIL` line names the row: `auto` mode must write nothing, and each other mode must rewrite `ls -la`.

### M7

```sh
command -v actionlint shellcheck hadolint ruff go staticcheck gofmt shfmt mdformat
```

Expected: All resolve.

### M12

```sh
bash "$(jq -r '.plugins["whetstone@raisedadead-plugins"][0].installPath' ~/.claude/plugins/installed_plugins.json)/bin/claim-check" AGENTS.md docs/README.md docs/ARCHI.md docs/MAINTENANCE.md
```

Expected: Exit 0 and `CLAIMS: CLEAN`.

### M15

In a throwaway super and sub repository pair with both hooks on `core.hooksPath`, run in the sub: `commit`, `commit --amend`, `commit --amend --date=2001-02-03`.

Expected: The super tip reads `chore(sub): bump to <sha>`. After each amend, the super has one bump commit with the new sha, the super author and the super date.

### M16

Feed `.githooks/pre-push` a stdin ref line whose sha records a pushed submodule commit. Then feed one whose gitlink is on no submodule remote.

Expected: Exit 0, then exit 1 with the submodule, the gitlink and the push command.
