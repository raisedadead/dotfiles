# Maintenance checks

Used by `~/.claude/loop.md` and manual audits. Diagnose only: do not apply, repair, update, or commit during a check. Run each applicable probe and compare its result with the pass criterion. Report failures and skipped checks, one line each.

## Terminal stack

| ID | Probe | Pass criterion |
| --- | --- | --- |
| T1 | `ghostty +validate-config`; `ghostty +show-config` | No configuration errors; effective shell integration retains `path` |
| T2 | `(for f in ~/.zshenv ~/.config/zsh/.zshenv ~/.config/zsh/.zprofile ~/.config/zsh/.zshrc ~/.config/zsh/*.zsh; do zsh -n "$f" || exit; done)` | Syntax succeeds |
| T3 | Probe `whence -p node brew zsh` and `print -l $path` in bare, interactive, login-interactive, and `env -i` zsh | fnm node and Homebrew resolve ahead of system alternatives; user commands retain precedence |
| T4 | `zsh -ic 'print -l $fpath'`; compare `bindkey` before/after startup changes | fpath has no duplicates; Ctrl+R uses Atuin, Ctrl+T uses the file widget, Ctrl+F uses mdr |
| T5 | In a new shell: `chezmoi re-add ~/.config/zsh/<Tab>` and `home re-add ~/.config/zsh/<Tab>`; select, then cancel the command line | Picker includes dotfiles; selection completes a target path |
| T6 | Ctrl+T on an empty argument, `~/.config/zsh/fz`, a quoted path with spaces, and a word before another argument; repeat with Escape | Root/query follow the argument; selection replaces it; surrounding text and cancellation remain intact |
| T7 | Ctrl+T in a temporary Git fixture with hidden files, ignored files, directories, and a binary; press `<C-g>` | Default respects ignores; explicit include reveals ignored paths; previews fit the entry type |
| T8 | Compare each `plugins.lock` revision with `git -C "$ZPLUGDIR/<repo-name>" rev-parse HEAD` | Recorded and installed revisions agree; do not update as part of this check |
| T9 | Run `shellcheck` on changed tmux Bash scripts; parse and load tmux config on an isolated socket (below) | No new diagnostics; no effect on live sessions |
| T10 | `tmux list-clients -F '#{client_termname}: #{client_termfeatures}'`; `tmux show -g extended-keys`; inspect root bindings | Ghostty capabilities and dual Alt+Shift routing agree with [ARCHI.md](ARCHI.md#terminal-stack) |
| T11 | Exercise `M-H/J/K/L` across shell panes and Neovim splits; Ctrl+Shift+W/E/A/S in shell and editor; copy text | Correct consumer gets each key; clipboard works; shell Ctrl+Shift+W deletes to line start |
| T12 | Switcher: search a file deeper than four directories and a text match after line 5,000; change query, switch Files/Grep, bookmark a directory | Deep and late matches appear; query reloads; file mode restores fuzzy search; bookmark marker stays visible |
| T13 | `nvim --headless '+checkhealth' +qa`; compare lazy-lock entries with installed plugin HEADs | Inspect provider/tool failures; lock and installed revisions agree |
| T14 | Save temporary Markdown with two trailing spaces and Lua with trailing spaces; repeat Lua with autoformat disabled; open a source buffer | Markdown hard break remains; enabled Lua trim runs; disabled trim does not; source buffer has no implicit chezmoi apply hook |
| T15 | Compare repeated `/usr/bin/time -p zsh -ic exit` runs; use `ZPROF=true zsh -ic exit` for attribution | Compare medians with a same-machine baseline; investigate measured regressions |
| T16 | Compare shader on/off with equal window size, display, text, focus, and scroll workload | Record CPU and GPU/energy separately; do not infer battery savings from CPU alone |

For tmux probes, use a unique explicit `-L` or `-S` on **every** command, including cleanup. `-f /dev/null` selects a config, not a server. `TMUX_TMPDIR` does not override an inherited `$TMUX`. If the tested config spawns bare `tmux`, give it a temporary PATH wrapper that adds the same `-S` socket. Parse output can contain errors even when tmux exits zero. Read it.

Use disposable fixtures for write and key-routing checks. A completion test must not execute the completed `re-add` command. For interactive tests, inspect the actual picker as well as the resulting buffer.

## Agent rig

| ID | Probe | Pass criterion |
| --- | --- | --- |
| M1 | `~/.bin/chezmoi-claude-doctor.sh` | Exit 0; no `WARN:`, `ORPHAN:`, or `LINT:` lines |
| M2 | `claude plugin list`; compare installed `gitCommitSha` with `git -C ~/DEV/rd/claude-code-plugins rev-parse HEAD` | Expected plugins enabled; first-party revisions agree, or report the gap |
| M3 | `claude mcp list` | Configured servers connect; report scope conflicts |
| M4 | `~/.bin/chezmoi-claude-hooks-test.sh --all` | Both suites pass; report each suite's count. Tests isolate marker paths |
| M5 | `chezmoi diff` | Empty, or list drifted paths without applying |
| M6 | `rtk hook check 'grep -r x .'`; `rtk gain`; inspect `.bash_wrap` in `hook_config.json` and the corruption log | Each dispatcher-owned command returns `No rewrite` from the native hook; fewer than five corruption entries in seven days |
| M7 | `command -v actionlint shellcheck hadolint ruff go staticcheck gofmt shfmt mdformat` | Required validator binaries resolve |
| M8 | Inspect `~/.claude/markers` | Fewer than 400 files; no non-exempt file older than two days |
| M9 | Inspect Cavemem worker state and M3 | `lastError` is null; MCP connects |
| M10 | Compare deployed skill directories/symlinks with `~/.local/state/skills/.skill-lock.json`, source `cmd-*`, and installed plugin registrations | Each skill has an owner; no broken symlinks |
| M11 | Search each `exact_dot_bin/` script and `dot_claude/workflows/*.js` name across the rig and this documentation, excluding itself | Each has a consumer or appears in [Operator tools](ARCHI.md#operator-tools) or the workflow registry |
| M12 | Run the claim checker below | Exit 0 and `CLAIMS: CLEAN` |
| M13 | `git -C ~/.dotfiles submodule status dot_claude`; `git -C ~/.dotfiles/dot_claude config core.hooksPath` | Value is `.githooks`. A leading `+` means the worktree and the gitlink disagree: `git add dot_claude` and commit when the worktree is ahead, `git submodule update dot_claude` when it is behind. After a fresh clone run `git submodule update --init` and set the hook path
| M14 | `git config --get push.recurseSubmodules`; `git config --get submodule.recurse`; `git config --get submodule.dot_claude.update`; `git config --get status.submoduleSummary` | `on-demand`, `false`, `merge`, and `true`: a parent push sends unpushed submodule commits first; `pull` and `checkout` leave the submodule working tree alone; `git submodule update` without `--checkout` or `--force` reports `Already up to date.` while the branch is ahead; the parent `git status` lists pending submodule commits
| M15 | In a throwaway super/sub pair with both hooks on `core.hooksPath`: commit in the sub, then `commit --amend` in the sub, then `commit --amend --date=2001-02-03` in the sub | After the first commit the super tip reads `chore(sub): bump to <sha>`; after each amend the super still has one bump commit and it records the new sha; the bump author and date are the super defaults, not the sub commit values
| M16 | Feed `.githooks/pre-push` a stdin ref line whose local sha records a pushed submodule commit, then one whose gitlink is on no submodule remote | Exit 0, then exit 1 naming the submodule, the gitlink, and its push command

```sh
bash "$(jq -r '.plugins["whetstone@raisedadead-plugins"][0].installPath' ~/.claude/plugins/installed_plugins.json)/bin/claim-check" ARCHI.md MAINTENANCE.md CLAUDE.md
```

Dispatcher or hook-rule edits require M4. Validator/formatter registry edits require the spec smoke test. Plugin upgrades require M1–M3. Use the terminal checks for shell, Ghostty, tmux, or Neovim changes; the agent doctor does not replace them.
