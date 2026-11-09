# Skill composition

The kernel holds the precedence rules. This document holds the order. The UI workflow uses shared skill names for Pi and Claude Code. Other sections use Claude Code skill names.

A task has one driver. Every other skill is a reference. A driver runs the loop. A reference gives a rubric that you read and apply. Do not use two drivers on one task. Two drivers give two reports and no decision.

Follow the order. A design skill that you read after the code exists can only criticise the code. It cannot shape the design.

## Change behaviour

A feature, a bug fix, or any change to what the code does.

1. `whetstone:tdd-cycle` drives. In a live dossier, `dossier:build` drives instead.
1. Read `test-driven-development` when you must decide what to test.
1. `reviewer` or the `lens-review` workflow before done. `args.spec` adds the spec lens. `/code-review` runs only when the operator asks for it.

## Change a public interface

A REST or GraphQL endpoint, an exported type, a module boundary, or a config schema.

1. `api-and-interface-design` first, before a test exists.
1. `whetstone:codebase-design` when the change moves a module boundary or its depth.
1. `whetstone:doubt-pass` when the decision is costly to reverse.
1. Then "Change behaviour" above.

## Answer a design question

A state model, a UI flow, or a project term that is not clear yet.

1. `whetstone:prototype` builds a throwaway version before the real one.
1. `whetstone:domain-modeling` owns the project terms, `GLOSSARY.md` and the ADRs.

## Reduce complexity

The code is correct, and it is harder to read than it must be.

1. `code-simplification` names the defect and its signal.
1. `/simplify` applies the fix.
1. `whetstone:tiger-style` checks the column budget last.

Do not start here for a defect. A defect goes to "Find a defect".

## Find a defect

A bug report, a wrong result, or a performance regression.

1. `whetstone:diagnose` drives.
1. `performance-optimization` holds the rubric for a slow path.
1. `cloudflare:web-perf` covers Core Web Vitals in a browser alone.
1. `dossier:backprop` after the fix, when a new invariant prevents the recurrence.

For a visual layout defect whose cause is known, use the UI workflow below.

## Build or polish a screen

1. Resolve the scope before selecting a skill. Identify the page shell (navigation, main area and table of contents), the content container (titles, cards, code and tables), and the prose. Record the requested outcome, project tokens and accepted design constraints.
1. Select one driver. `better-layout` drives a new screen, a redesign, or a change to shared widths or breakpoints. A focused skill drives an isolated concern: `better-typography`, `better-colors`, `better-accessibility`, `better-ui`, or `better-writing`. A typography request alone keeps the accepted layout. For an unexplained rendering or interaction failure, diagnosis drives first: `diagnosing-bugs` in Pi or `whetstone:diagnose` in Claude Code. Use UI skills as references until the cause is known.
1. Read the applicable references before code. Use this design order: layout, writing, typography, color, then UI polish. Apply `better-accessibility` throughout. Load only the references the scope needs; they do not become additional drivers.
1. Set the layout before type: how the rails and main area share space, how the content container grows, and when columns collapse. Prose measure is separate from content width. A character-count guide checks paragraphs only, not cards, code, tables or the page. An accepted project decision, such as a prose measure, takes precedence over a numeric guide, but you still fix an accessibility failure. Ask the operator before a conflict changes the scope or design.
1. Use the project's tokens and components. Check every consumer of a shared change. If a focused task needs a layout change, resolve that scope before you edit the shared layout.
1. Verify in the browser. For layout work, inspect the full screen at the narrowest, typical desktop and widest supported widths: proportions, use of space, wrapping, content fit, overflow, keyboard and zoom. For an isolated change, inspect the affected components, states, themes and accessibility checks. Compare with the accepted reference or before state. Numeric checks support visual acceptance and do not replace it. Report unverified coverage.
1. Use `better-interface` for a new screen, a redesign, or an explicit whole-interface review, at most once at the end. Load `better-layout` before `better-interface`, also for a review; both rigs refuse `better-interface` until `better-layout` has loaded in the session. Other tasks use focused acceptance, which does not approve the whole interface.

The operator runs `/interface-review`; the model cannot invoke it.

## Harden a boundary

Authentication, input from a user, a webhook, or a new dependency.

1. `security-review`, a Claude Code built-in, reads the change on the branch.
1. `ghsa-draft` drafts a freeCodeCamp advisory alone.

## Guide the operator

Several manual steps: credentials, a third-party dashboard, or a cutover.

1. `whetstone:wizard` drives.

## Signals that the pick is wrong

- Two skills give the same report. One of them is not a driver.
- A skill fires because its description matched, and its rubric does not apply to the task.

Do the work when no recipe applies.
