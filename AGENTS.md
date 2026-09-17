# Dotfiles

Public chezmoi source: `~/.dotfiles`. It is the source of truth for this machine's configuration and for the coding-agent rigs. `CLAUDE.md` is a symlink to this file, so every agent reads the same instructions.

Three coding agents run here: Claude Code, Codex, and Pi. [Agent rigs](docs/ARCHI.md#agent-rigs) holds the map, the rig contract, and the skill rules.

## Documents

- This file: the entry point, and the rules for a change here.
- [docs/ARCHI.md](docs/ARCHI.md): ownership, load order, the agent rigs, and the constraints. It is the main context for this project.
- [docs/MAINTENANCE.md](docs/MAINTENANCE.md): the checks. Its first table selects the checks for your change.
- [docs/SKILLS.md](docs/SKILLS.md): the order in which skills compose. The Claude kernel holds the precedence.
- [docs/README.md](docs/README.md): the install steps and the chezmoi commands for daily work.

The files under `docs/` are shared. Every coding agent reads them.

## Rules

- Read [docs/ARCHI.md](docs/ARCHI.md) before a configuration change.
- Run the checks in [docs/MAINTENANCE.md](docs/MAINTENANCE.md) after a change.
- Keep README.md and the files under docs/ current and concise. Keep audit history in private owner documentation.
- Private directories, such as `dot_claude/`, are submodules of the private repository, one branch per directory. Do not change `dot_claude/` without an explicit request for that submodule.
- Before you change an installed target, show its proposed diff and ask the operator.
- Each agent owns its own global kernel. Do not edit another agent's kernel. Report the change you want instead.

The operator requests a completed reviewer before completion for each non-trivial source change that affects two or more source files. The operator owns pushes, pull requests, releases, and infrastructure changes.
