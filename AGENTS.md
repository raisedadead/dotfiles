# Dotfiles

Public chezmoi source: `~/.dotfiles`. It is the source of truth for this machine's configuration and for the coding-agent rigs.

Two coding agents run here: Claude Code and Pi.

## Documents

- [docs/ARCHI.md](docs/ARCHI.md): ownership, load order, the agent rigs, and the constraints. It is the main context for this project. Read it before a configuration change.
- [docs/MAINTENANCE.md](docs/MAINTENANCE.md): the checks. Its first table selects the checks for your change.
- [docs/SKILLS.md](docs/SKILLS.md): the order in which skills compose.
- [docs/README.md](docs/README.md): the install steps and the chezmoi commands for daily work.

## Rules

- Run the checks in [docs/MAINTENANCE.md](docs/MAINTENANCE.md) after a change.
- Keep README.md and docs/ current and concise. Keep audit history in private owner documents.
- Private directories, such as `dot_claude/`, are submodules of the private repository, one branch per directory. Do not change `dot_claude/` without an explicit request for that submodule.
- Edit another agent's kernel only when the operator asks. The operator owns releases and infrastructure changes.
