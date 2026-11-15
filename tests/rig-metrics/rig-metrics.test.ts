import { afterEach, beforeEach, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";

const RIG_METRICS = resolve(import.meta.dir, "../../exact_dot_bin/executable_rig-metrics");
const UNTIL = "2026-11-12";
const TS = "2026-11-12T10:00:00.000Z";

let home: string;
let ids = 0;

const run = (...args: string[]) => {
  const proc = Bun.spawnSync(["bun", RIG_METRICS, ...args], { env: { PATH: process.env.PATH ?? "", HOME: home } });
  return { code: proc.exitCode, out: proc.stdout.toString(), err: proc.stderr.toString() };
};

const report = (...args: string[]) => {
  const { code, out, err } = run(...args);
  if (code !== 0) throw new Error(`exit ${code}: ${err}`);
  return JSON.parse(out);
};

const put = (path: string, rows: unknown[]) => {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, rows.map(row => JSON.stringify(row)).join("\n") + "\n");
};

const session = (rows: unknown[], project = "-Users-op-repo", name = `s${++ids}.jsonl`) => put(join(home, ".claude/projects", project, name), rows);

const says = (text: string, extra: Record<string, unknown> = {}) => ({ type: "user", timestamp: TS, origin: { kind: "human" }, message: { role: "user", content: text }, ...extra });

const result = (text: string, isError = true, ts = TS) => ({
  type: "user",
  timestamp: ts,
  message: { role: "user", content: [{ type: "tool_result", tool_use_id: `tu_${++ids}`, is_error: isError, content: [{ type: "text", text }] }] },
});

beforeEach(() => {
  home = mkdtempSync(join(tmpdir(), "rig-metrics-"));
});

afterEach(() => rmSync(home, { recursive: true, force: true }));

test("a short message that opens with a correction counts, and other messages do not", () => {
  session([
    says("No, land it on main."),
    says("STOP GUESSING,"),
    says("Why did you miss the root password issue."),
    says("I do not want a PR for this."),
    says("Now add the test for the parser."),
    says("Please do not stop until the build is green."),
    says(`No. ${"x".repeat(300)}`),
  ]);
  const { total } = report("--until", UNTIL, "7");
  expect(total).toMatchObject({ operatorMessages: 7, corrections: 4, correctionsPer100: 57.1 });
});

test("only the operator's own messages count", () => {
  session([
    says("No, wrong repo."),
    says("<bash-input>git status</bash-input>"),
    says("<task-notification>done</task-notification>"),
    says("This session is being continued from a previous conversation."),
    says("No, not this.", { isMeta: true }),
    says("No, not this.", { isSidechain: true }),
    says("No, not this.", { origin: { kind: "task-notification" } }),
    says("Stop.", { origin: undefined, turnOrigin: "human" }),
    says("Stop.", { origin: undefined, turnOrigin: "human", promptSource: "sdk" }),
  ]);
  session([says("No, wrong.")], "-Users-op-repo", "s/subagents/agent-a1.jsonl");
  session([says("No, wrong.")], "-private-tmp-oneshot-probe");
  session([says("No, wrong.", { cwd: "/private/tmp/rigfx-1" })]);
  const { total } = report("--until", UNTIL, "7");
  expect(total).toMatchObject({ operatorMessages: 2, corrections: 2 });
});

test("a rig refusal counts, and a harness error or a passing result does not", () => {
  session([
    result("<tool_use_error>The rig cannot read a command built at run time.</tool_use_error>"),
    result("This command requires approval"),
    result("Permission to use Bash with command git push has been denied."),
    result("TaskCreated hook feedback: Task name is outside the form"),
    result("<tool_use_error>String to replace not found in file.</tool_use_error>"),
    result("File has been modified since read"),
    result("<tool_use_error>InputValidationError: bad input</tool_use_error>"),
    result("exit 1: tests failed"),
    result("<tool_use_error>looks like one, but passed</tool_use_error>", false),
    result("ok", false),
  ]);
  session([result("A gatherer agent may run only: rg", true), result("<tool_use_error>A gatherer agent may run only: rg</tool_use_error>")], "-Users-op-repo", "s/subagents/agent-a2.jsonl");
  const { total } = report("--until", UNTIL, "7");
  expect(total).toMatchObject({ toolResults: 12, refusals: 5, refusalsPer100: 41.7 });
});

test("the numbers come per ISO week, inside the window only", () => {
  session([
    result("This command requires approval", true, "2026-11-02T10:00:00.000Z"),
    result("ok", false, "2026-11-08T23:59:59.000Z"),
    result("This command requires approval", true, "2026-11-09T00:00:00.000Z"),
    result("This command requires approval", true, "2026-10-01T00:00:00.000Z"),
    result("This command requires approval", true, "2026-11-13T00:00:00.000Z"),
    says("No."),
  ]);
  const { window, weeks } = report("--until", UNTIL, "14");
  expect(window).toEqual({ since: "2026-10-30", until: UNTIL, days: 14 });
  expect(weeks).toEqual([
    { week: "2026-W45", operatorMessages: 0, corrections: 0, toolResults: 2, refusals: 1, correctionsPer100: 0, refusalsPer100: 50 },
    { week: "2026-W46", operatorMessages: 1, corrections: 1, toolResults: 1, refusals: 1, correctionsPer100: 100, refusalsPer100: 100 },
  ]);
});

test("an empty home prints zeros, and a bad argument exits 64 with the usage", () => {
  expect(report("--until", UNTIL).total).toEqual({ operatorMessages: 0, corrections: 0, toolResults: 0, refusals: 0, correctionsPer100: 0, refusalsPer100: 0 });
  for (const args of [["triggers"], ["--until", "soon"], ["7", "8"], ["0"]]) {
    const { code, err } = run(...args);
    expect(code).toBe(64);
    expect(err).toContain("usage: rig-metrics [--until YYYY-MM-DD] [days]");
  }
});
