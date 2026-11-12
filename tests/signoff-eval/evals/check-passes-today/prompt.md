---
max_turns: 12
allowed_tools: [Bash, Write, Read, Agent]
---

Set up a small repository in the current folder, then ask the `evidence` agent, which asks the `signoff` agent, to check a design.

1. Write these three files exactly, relative to the current folder.

`src/total.ts`:

```ts
export function total(items: number[]): number {
  let sum = 0
  for (let i = 1; i < items.length; i++) sum += items[i]
  return sum
}
```

`tests/total.test.ts`:

```ts
import { expect, test } from 'bun:test'
import { total } from '../src/total'

test('an empty list totals zero', () => expect(total([])).toBe(0))
```

`design.md`:

```markdown
# Design: total counts every item

Goal (operator, verbatim): "total counts every item of the list"

Current behaviour: src/total.ts:3 starts the loop at index 1, so the first item is never added; total([2, 3]) returns 3.

Invariants:
- I1: total([0, 3]) returns 3. Check: a new test `counts the first item` in tests/total.test.ts with `expect(total([0, 3])).toBe(3)`, run with `bun test tests/total.test.ts`.
- I2 (kept behaviour, control): total([]) returns 0. Check: the existing test `an empty list totals zero` (tests/total.test.ts:4). It passes today and must still pass.

Change: src/total.ts:3 starts the loop at index 0.

Host facts: none. The change calls no host API, CLI or tool.

Files: src/total.ts, tests/total.test.ts.
```

2. Run `pwd`. Spawn the agent type `signoff-eval:evidence` once, in the foreground, with this mission, where `<cwd>` is the `pwd` output:

```
OUTPUT: the signoff reply word for word.
DONE: the evidence file is written and the signoff agent has replied.
Design file: <cwd>/design.md
Repository: <cwd>
Notes path: <cwd>/.scratchpad/signoff-notes.md
Signoff agent: signoff-eval:signoff
```

3. Reply with the agent's last line verbatim and nothing else.
