# Skill composition

This document gives the order in which skills compose. The kernel holds the precedence rules.

A task has one driver. Every other skill is a reference: it gives a rubric that you read and apply. Do not use two drivers on one task.

Follow the order. A design skill that you read after the code exists can only criticise the code.

## Prefixes

`cmd-` means the operator usually starts the skill. `rig-` means the model loads the skill on its own. Neither prefix changes who can run it.

## First-party skills

- `cmd-status` reports where the work stands. It changes nothing.
- `cmd-continue` picks up the newest handoff or the next open-work line.
- `cmd-handoff` writes a handoff file for another session or person.
- `cmd-recall` finds what was done or decided before.
- `cmd-wrist-tap` halts the work after a deviation and forces a root-cause check.
- `cmd-refresh-plugins` updates the installed plugins.
- `cmd-watch-pane` watches a tmux or Rex pane.
- `cmd-audit-kernel` audits the kernel, the rules and the skill descriptions.
- `cmd-audit-scratchpad` proposes a cleanup of `.scratchpad/`.
- `cmd-add-skill` installs a third-party skill.
- `cmd-ghsa` drafts a freeCodeCamp security advisory.
- `rig-plan` writes a plan and gets it checked. In a repo with `.scratchpad/dossier/`, `dossier:plan` drives the plan.
- `rig-secrets` holds the steps for a 1Password item. Read it before the first `op` call.
- `rig-chezmoi` changes or repairs a chezmoi-managed file.
- `rig-docs` writes a manual in ASD-STE100.

## Change behaviour

1. `whetstone:tdd-cycle` drives. In a live dossier, `dossier:build` drives.
1. Run one `reviewer` before the push. Run `/code-review` when the operator asks.

## Change a design

1. `whetstone:codebase-design` when the change moves a module boundary.
1. `whetstone:doubt-pass` when the decision is costly to reverse.
1. `whetstone:grill` when a request has several readings.
1. `whetstone:prototype` builds a throwaway version to answer a design question.
1. `whetstone:domain-modeling` owns the project terms, `GLOSSARY.md` and the ADRs.

## Reduce complexity

1. `/simplify` applies the fix.
1. `whetstone:tiger-style` checks the column budget last.

## Find a defect

1. `whetstone:diagnose` drives.
1. `cloudflare:web-perf` covers Core Web Vitals.
1. `dossier:backprop` follows the fix, when a new check prevents the recurrence.

## Check a claim or write a report

- `whetstone:research-report` runs the `verify-claims` workflow to check sourced claims.
- `dossier:verify` checks a version or other fact that can be stale.
- `whetstone:research-report` and `whetstone:html-report` write a report.
- `whetstone:skill-smith` lints a `SKILL.md`.

## Harden a boundary

Use `security-review` for authentication, user input, a webhook or a new dependency.

## Other plugin skills

- `worktrunk:*` covers the `wt` command.
- `cloudflare:*` covers Cloudflare products.
- `dossier:close` and `dossier:ship` end a dossier.

UI work has no driver skill.

If no recipe applies, do the work.
