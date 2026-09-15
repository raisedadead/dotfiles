# Skill composition

The kernel holds the precedence rules. This document holds the order.

A task has one driver. Every other skill is a reference. A driver runs the loop. A reference gives a rubric that you read and apply. Two drivers on one task give two reports and no decision.

Order is not a preference. A design skill that you read after the code exists is a critic, not a design.

## Change behaviour

A feature, a bug fix, or any change to what the code does.

1. `whetstone:tdd-cycle` drives. In a live dossier, `dossier:build` drives instead.
1. Read `test-driven-development` when you must decide what to test. It holds the test pyramid ratios, the real-fake-stub-mock order, and the named anti-patterns.
1. `reviewer` before done.

## Change a public interface

A REST or GraphQL endpoint, an exported type, a module boundary, or a config schema.

1. `api-and-interface-design` first, before a test exists.
1. `whetstone:doubt-pass` when the decision is costly to reverse.
1. Then "Change behaviour" above.

## Reduce complexity

The code is correct, and it is harder to read than it must be.

1. `code-simplification` names the defect and its signal.
1. `/simplify` applies the fix.
1. `whetstone:tiger-style` checks the column budget last.

Do not start here for a defect. A defect goes to "Find a defect".

## Find a defect

A bug report, a wrong result, or a performance regression.

1. `mattpocock-skills:diagnosing-bugs` drives. It bisects, and it measures before it changes code.
1. `performance-optimization` holds the rubric for a slow path: cache keys, pool size, N+1 queries, and the attempt ledger.
1. `cloudflare:web-perf` covers Core Web Vitals in a browser alone.
1. `dossier:backprop` after the fix, when a new invariant prevents the recurrence.

## Build or polish a screen

1. One focused skill for a named concern: `better-typography`, `better-colors`, `better-layout`, `better-accessibility`, `better-ui`, or `better-writing`.
1. `interface-review` for a full sweep at the end.

`better-interface` and `interface-review` are both full sweeps. Run one.

## Harden a boundary

Authentication, input from a user, a webhook, or a new dependency.

1. `rules/07-owasp.md` loads with the kernel. It is the floor, not a step.
1. `security-review` reads the change on the branch.
1. `ghsa-draft` drafts a freeCodeCamp advisory alone.

## Signals that the pick is wrong

- Two skills give the same report. One of them is not a driver.
- A design skill runs after the code exists.
- A skill fires because its description matched, and its rubric does not apply to the task.
- The task needs no rubric, and a skill is open.

Do the work when no recipe applies. Do not open a skill to look busy.
