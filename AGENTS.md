# Dotfiles

Public chezmoi source: `~/.dotfiles`. Private directories, such as `dot_claude/`, are submodules of the private repository, one branch per directory.

- Read [docs/ARCHI.md](docs/ARCHI.md) before a configuration change.
- Run the checks in [docs/MAINTENANCE.md](docs/MAINTENANCE.md) after a change.
- Keep README.md and the files under docs/ current and concise. Keep audit history in private owner documentation.

The operator requests a completed reviewer before completion for each non-trivial source change that affects two or more source files. The operator owns pushes, pull requests, releases, and infrastructure changes.

Do not change `dot_claude/` without an explicit request for that submodule. Before changing an installed target, show its proposed diff and ask the operator.
