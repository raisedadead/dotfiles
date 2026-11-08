import { expect, test } from "bun:test";
import {
  addedLines,
  cleanLine,
  endLine,
  errorLine,
  isShell,
  parseElapsed,
  promptLine,
  repeatKey,
  splitComplete,
} from "../../dot_claude/skills/cmd-monitor-pane/scripts/executable_watch-pane.ts";

test("cleanLine drops colour, title and cursor sequences", () => {
  expect(cleanLine("\x1b[31mfatal:\x1b[0m [web1]")).toBe("fatal: [web1]");
  expect(cleanLine("\x1b]0;title\x07ok")).toBe("ok");
  expect(cleanLine("\x1b]8;;http://x\x1b\\link\x1b]8;;\x1b\\")).toBe("link");
  expect(cleanLine("\x1b[2K\x1b[1Gdone")).toBe("done");
  expect(cleanLine("\x1b(Bplain")).toBe("plain");
});

test("cleanLine keeps the last carriage-return segment with text", () => {
  expect(cleanLine("10%\r50%\r100%")).toBe("100%");
  expect(cleanLine("progress\r")).toBe("progress");
  expect(cleanLine("abc\b\bX")).toBe("aX");
});

test("splitComplete stops at the last newline and keeps the partial line", () => {
  const { lines, consumed, partial } = splitComplete(Buffer.from("one\r\ntwo\nthr"));
  expect(lines).toEqual(["one", "two"]);
  expect(consumed).toBe(9);
  expect(partial).toBe("thr");
});

test("errorLine wakes on error shapes and skips zero counts", () => {
  for (const line of [
    "fatal: [web1]: FAILED! => {}",
    "Error: connect ECONNREFUSED",
    "Traceback (most recent call last):",
    "ulimit: Too many open files: error",
    "web2 : ok=3 changed=0 unreachable=1 failed=0",
  ]) {
    expect(errorLine(line)).toBe(true);
  }
  for (const line of [
    "web1 : ok=5 changed=1 unreachable=0 failed=0 skipped=0",
    "0 failed, 12 passed",
    "errors: 0",
    "No errors found",
    "TASK [install nginx]",
  ]) {
    expect(errorLine(line)).toBe(false);
  }
});

test("errorLine knows shell and system errors and skips healthy names", () => {
  for (const line of [
    "ulimit: Too many open files",
    "zsh: command not found: foo",
    "cat: x: No such file or directory",
    "npm ERR! code E404",
    "E: Unable to locate package nginx",
    "--- FAIL: TestJev (0.01s)",
  ]) {
    expect(errorLine(line)).toBe(true);
  }
  for (const line of [
    "✓ rejects with error on timeout [1.20ms]",
    "(pass) jev > errors stay local",
    "TASK [nginx : Check config for errors] ****",
    'ok: [web1] => {"changed": false, "failed": false}',
    "ok  \tgithub.com/x/y\t0.120s",
    'go: downloading github.com/pkg/errors v0.9.1',
    '      + key = "error.html"',
    "tests/errors/test_parse.py ....",
    "Unable to find image 'nginx:latest' locally",
  ]) {
    expect(errorLine(line)).toBe(false);
  }
});

test("repeatKey ignores numbers so a crash loop wakes once", () => {
  expect(repeatKey("2026-11-08 12:00:01 ERROR retry 3")).toBe(repeatKey("2026-11-08 12:00:11 ERROR retry 4"));
});

test("endLine knows ansible, terraform and test runner summaries", () => {
  for (const line of [
    "PLAY RECAP *********************************************************************",
    "Apply complete! Resources: 2 added, 0 changed, 0 destroyed.",
    "No changes. Your infrastructure matches the configuration.",
    "Ran 52 tests across 2 files. [120.00ms]",
    "Tests:       5 passed, 5 total",
    "      Tests  2434 passed (2435)",
    "===== 3 passed, 1 failed in 0.52s =====",
  ]) {
    expect(endLine(line)).toBe(true);
  }
  for (const line of [
    "TASK [Gathering Facts] ****",
    "ok: [web1]",
    "Plan: 3 to add, 0 to change, 0 to destroy.",
    "ok  \tgithub.com/x/y\t0.120s",
  ]) {
    expect(endLine(line)).toBe(false);
  }
});

test("promptLine knows input prompts", () => {
  for (const line of ["Continue? [y/N] ", "Password:", "Are you sure (yes/no/[fingerprint])? ", "Press Enter to continue"]) {
    expect(promptLine(line)).toBe(true);
  }
  expect(promptLine("Downloading 45%")).toBe(false);
  expect(promptLine("")).toBe(false);
});

test("isShell ignores the login dash", () => {
  expect(isShell("-zsh")).toBe(true);
  expect(isShell("bash")).toBe(true);
  expect(isShell("python3.12")).toBe(false);
});

test("addedLines finds new lines after a repeated block", () => {
  const block = Array.from({ length: 25 }, (_, i) => `line ${i}`);
  const prev = [...block];
  const cur = [...block, ...block, "ERROR after repeat"];
  expect(addedLines(prev, cur)).toEqual({ lines: [...block, "ERROR after repeat"], lost: false });
});

test("addedLines keeps new text before a block that repeats the anchor", () => {
  const block = Array.from({ length: 20 }, (_, i) => `retry ${i}`);
  const older = Array.from({ length: 30 }, (_, i) => `old ${i}`);
  const prev = block;
  const cur = [...older, ...block, "Y new", ...block];
  expect(addedLines(prev, cur, older.length + block.length)).toEqual({ lines: ["Y new", ...block], lost: false });
});

test("addedLines calls a full scrollback with a repeated anchor lost, not new", () => {
  const block = Array.from({ length: 20 }, (_, i) => `retry ${i}`);
  const cur = [...block, "Y fatal: disk full", ...block, "tail"];
  expect(addedLines(block, cur, cur.length).lost).toBe(true);
});

test("parseElapsed reads ps etime", () => {
  expect(parseElapsed("05:07")).toBe(307000);
  expect(parseElapsed("01:02:03")).toBe(3723000);
  expect(parseElapsed("2-00:00:01")).toBe(172801000);
  expect(parseElapsed("x")).toBeUndefined();
});

test("addedLines reports a lost anchor", () => {
  expect(addedLines(["a", "b"], ["x", "y"])).toEqual({ lines: ["x", "y"], lost: true });
  expect(addedLines([], ["x"])).toEqual({ lines: ["x"], lost: false });
});
