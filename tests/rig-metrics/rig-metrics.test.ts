import { afterEach, beforeEach, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";

const RIG_METRICS = resolve(import.meta.dir, "../../exact_dot_bin/executable_rig-metrics");
const UNTIL = "2026-11-12";
const DAY_TS = "2026-11-12T10:00:00.000Z";

let home: string;
let ids = 0;

const env = () => ({ PATH: process.env.PATH ?? "", HOME: home, GIT_CONFIG_GLOBAL: "/dev/null", GIT_CONFIG_NOSYSTEM: "1" });

const run = (...args: string[]) => {
  const proc = Bun.spawnSync(["bun", RIG_METRICS, ...args], { env: env() });
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

const usage = (extra: Record<string, unknown> = {}) => ({
  input_tokens: 1_000_000,
  output_tokens: 0,
  cache_read_input_tokens: 0,
  cache_creation: { ephemeral_5m_input_tokens: 0, ephemeral_1h_input_tokens: 0 },
  ...extra,
});

const prompt = (ts = DAY_TS) => ({ type: "user", timestamp: ts, entrypoint: "cli", origin: { kind: "human" }, message: { role: "user", content: "change it" } });

const step = (tools: { name: string; input: Record<string, unknown> }[] = [], opts: { ts?: string; effort?: string; id?: string; usage?: unknown } = {}) => ({
  type: "assistant",
  timestamp: opts.ts ?? DAY_TS,
  effort: opts.effort ?? "high",
  message: {
    id: opts.id ?? `msg_${++ids}`,
    model: "claude-opus-5-5",
    usage: opts.usage ?? usage(),
    content: tools.map(tool => ({ type: "tool_use", id: `tu_${++ids}`, ...tool })),
  },
});

const edit = (file = "/work/repo/src/a.ts") => ({ name: "Edit", input: { file_path: file } });
const review = (id: string) => ({ id, name: "Agent", input: { subagent_type: "reviewer", prompt: "review" } });
const spawned = (agentId: string, call: string, ts = DAY_TS) => ({ type: "user", timestamp: ts, message: { role: "user", content: [{ type: "tool_result", tool_use_id: call, content: "launched" }] }, toolUseResult: { agentId, status: "async_launched" } });

const project = (session: string, rows: unknown[]) => put(join(home, ".claude/projects/-work-repo", `${session}.jsonl`), rows);

const subagent = (session: string, agentId: string, type: string, verdict: string, end = DAY_TS) => {
  const base = join(home, ".claude/projects/-work-repo", session, "subagents", `agent-${agentId}`);
  const row = (timestamp: string, input: number, text: string) => ({ type: "assistant", timestamp, message: { id: `msg_${++ids}`, model: "claude-opus-5-5", usage: usage({ input_tokens: input }), content: [{ type: "text", text }] } });
  put(`${base}.jsonl`, [row(DAY_TS, end === DAY_TS ? 0 : 1_000_000, "Reading."), row(end, 0, `Findings.\n\n${verdict}`)]);
  writeFileSync(`${base}.meta.json`, JSON.stringify({ agentType: type }));
};

const reviewedRequest = (session: string, verdict: string, reworked: boolean, effort = "high", ts = DAY_TS) => {
  const agentId = `a${++ids}`;
  const call = `tu_${++ids}`;
  project(session, [prompt(ts), step([edit()], { effort, ts }), step([review(call)], { effort, ts }), spawned(agentId, call, ts), ...(reworked ? [step([edit("/work/repo/src/b.ts")], { effort, ts })] : [])]);
  subagent(session, agentId, "reviewer", verdict);
};

const outcome = (row: Record<string, unknown>) => ({ kind: "outcome", ts: DAY_TS, session: "s", request: 1, srcFiles: ["/work/repo/src/a.ts", "/work/repo/src/b.ts"], srcLines: 10, sheet: false, signoff: null, checksGreen: false, riskPath: false, reviews: 0, firstReview: null, editsAfterReview: 0, model: "claude-opus-5-5", effort: "high", ...row });

const git = (cwd: string, args: string[], date?: string) => {
  const extra = date ? { GIT_AUTHOR_DATE: date, GIT_COMMITTER_DATE: date } : {};
  const proc = Bun.spawnSync(["git", "-c", "user.name=t", "-c", "user.email=t@t", ...args], { cwd, env: { ...env(), ...extra } });
  if (proc.exitCode !== 0) throw new Error(proc.stderr.toString());
};

beforeEach(() => {
  home = mkdtempSync(join(tmpdir(), "rig-metrics-"));
  mkdirSync(join(home, ".claude/projects"), { recursive: true });
});

afterEach(() => rmSync(home, { recursive: true, force: true }));

test("prices every usage iteration, advisor included, and counts a repeated message id once", () => {
  const its = { iterations: [{ type: "message", model: "claude-opus-5-5", ...usage() }, { type: "advisor_message", model: "claude-fable-5-2", ...usage() }] };
  const row = step([], { id: "msg_same", usage: usage(its) });
  project("s1", [prompt(), row, row]);
  const { cost, advisor } = report("--until", UNTIL, "30");
  expect(cost.total).toBeCloseTo(4 + 8, 6);
  expect(advisor.mainCalls).toBe(1);
});

test("rework and all-spawn blocking rates follow the baseline definitions", () => {
  reviewedRequest("s1", "REVIEW: CHANGES — 1 blocker", true);
  reviewedRequest("s2", "REVIEW: 2 minor", true);
  reviewedRequest("s3", "REVIEW: clean", false);
  reviewedRequest("s4", "no verdict line here", false);
  const { reworkRate, blockingRateAllSpawns } = report("--until", UNTIL, "30");
  expect(reworkRate).toBeCloseTo(2 / 4, 6);
  expect(blockingRateAllSpawns).toBeCloseTo(1 / 3, 6);
});

test("the verdict is the last REVIEW or VERDICT line that starts a line", () => {
  reviewedRequest("s1", "**REVIEW:** CHANGES — 1 blocker\nThe notes quote PRE-REVIEW: clean.", false);
  reviewedRequest("s2", "REVIEW: PASS", false);
  const { blockingRateAllSpawns } = report("--until", UNTIL, "30");
  expect(blockingRateAllSpawns).toBeCloseTo(1 / 2, 6);
});

test("first-review rate reads the first review of each request through the Agent result", () => {
  const [first, second] = ["afirst", "asecond"];
  project("s1", [prompt(), step([edit()]), step([review("tu_r1")]), spawned(first, "tu_r1"), step([edit("/work/repo/b.ts")]), step([review("tu_r2")]), spawned(second, "tu_r2")]);
  subagent("s1", first, "reviewer", "REVIEW: clean");
  subagent("s1", second, "reviewer", "REVIEW: CHANGES — 1 major");
  reviewedRequest("s2", "REVIEW: CHANGES — 1 blocker", false);
  const { firstReviewBlockingRate, blockingRateAllSpawns } = report("--until", UNTIL, "30");
  expect(firstReviewBlockingRate).toBeCloseTo(1 / 2, 6);
  expect(blockingRateAllSpawns).toBeCloseTo(2 / 3, 6);
});

test("an outcome row with no review is unknown, not clean", () => {
  put(join(home, ".local/state/jev/route.jsonl"), [
    outcome({ reviews: 0 }),
    outcome({ reviews: 1, firstReview: "clean" }),
    outcome({ reviews: 1, firstReview: "minor", editsAfterReview: 2 }),
  ]);
  const { firstTimeRight } = report("--until", UNTIL, "30");
  expect(firstTimeRight).toEqual({ clean: 1, notClean: 1, unknown: 1 });
});

test("a fix commit on a changed file within 72 hours makes a clean review not clean", () => {
  const repo = join(home, "repo");
  mkdirSync(repo, { recursive: true });
  git(repo, ["init", "-q"]);
  writeFileSync(join(repo, "a.ts"), "one\n");
  git(repo, ["add", "a.ts"]);
  git(repo, ["commit", "-q", "-m", "feat: add a"], "2026-11-12T09:00:00Z");
  writeFileSync(join(repo, "a.ts"), "two\n");
  git(repo, ["commit", "-q", "-am", "fix: repair a"], "2026-11-13T09:00:00Z");
  put(join(home, ".local/state/jev/route.jsonl"), [
    outcome({ reviews: 1, firstReview: "clean", srcFiles: [join(repo, "a.ts")] }),
    outcome({ reviews: 1, firstReview: "clean", srcFiles: [join(repo, "b.ts")] }),
  ]);
  const { firstTimeRight } = report("--until", UNTIL, "30");
  expect(firstTimeRight).toEqual({ clean: 1, notClean: 1, unknown: 0 });
});

test("the until day bounds the window", () => {
  project("s1", [prompt(), step([], { usage: usage() })]);
  project("s2", [prompt("2026-11-13T10:00:00.000Z"), step([], { ts: "2026-11-13T10:00:00.000Z", usage: usage() })]);
  const { cost, window } = report("--until", UNTIL, "30");
  expect(cost.total).toBeCloseTo(4, 6);
  expect(window.until).toBe(UNTIL);
});

test("triggers lists every threshold as too few on an empty state and exits 0", () => {
  const { code, out } = run("triggers", "--until", UNTIL);
  expect(code).toBe(0);
  const rows = JSON.parse(out);
  for (const name of ["sheet kill rule", "effort A/B harm", "effort A/B default", "reviewer replay", "second-review labels", "optional review", "budget guard", "sign-off", "escalations", "handoff nudge"]) {
    const row = rows.find((r: { name: string }) => r.name === name);
    expect(row).toMatchObject({ name, status: "too few" });
    expect(row).toHaveProperty("figure");
    expect(row).toHaveProperty("n");
  }
});

test("baseline14 ends before the build day", () => {
  reviewedRequest("s1", "REVIEW: CHANGES — 1 blocker", false, "high", "2026-11-12T10:00:00.000Z");
  reviewedRequest("s2", "REVIEW: clean", false, "high", "2026-11-10T10:00:00.000Z");
  expect(report("--until", "2026-11-13", "30").baseline14.firstReviewBlockingRate).toBe(0);
});

test("reviewer replay reads the percentages of replay-notes.md and reports only", () => {
  const notes = join(home, "replay-notes.md");
  writeFileSync(notes, "sonnet-medium recall 64.1% (41/64)\nsonnet-high recall 79.7% (51/64)\nopus-medium recall 82.8% (53/64)\n");
  const row = report("triggers", "--until", UNTIL, "--replay", notes).find((r: { name: string }) => r.name === "reviewer replay");
  expect(row.rule).toBe("report only");
  expect(row.status).toBe("hold");
  expect(row.figure.recall["sonnet-medium"]).toBeCloseTo(0.641, 3);
  expect(row.figure.recall["sonnet-high"]).toBeCloseTo(0.797, 3);
  expect(row.figure.recall["opus-medium"]).toBeCloseTo(0.828, 3);
  expect(row.figure.gap["sonnet-medium"]).toBeCloseTo(-0.187, 3);
  expect(row.figure.gap["sonnet-high"]).toBeCloseTo(-0.031, 3);
  writeFileSync(notes, "sonnet-medium recall 0.85\nsonnet-high recall 64.1%\nopus-medium recall 82.8%\n");
  const plain = report("triggers", "--until", UNTIL, "--replay", notes).find((r: { name: string }) => r.name === "reviewer replay");
  expect(plain.figure.recall["sonnet-medium"]).toBeCloseTo(0.85, 3);
});

test("sign-off trigger reports count, cost, minutes and CHANGES rate from signoff spawns", () => {
  const agents = ["s1a", "s1b"];
  project("s1", [prompt()]);
  const tenMinutesLater = "2026-11-12T10:10:00.000Z";
  subagent("s1", agents[0], "signoff", "SIGNOFF: PASS", tenMinutesLater);
  subagent("s1", agents[1], "signoff", "SIGNOFF: CHANGES\nmissing: a check", tenMinutesLater);
  const rows = report("triggers", "--until", UNTIL);
  const row = rows.find((r: { name: string }) => r.name === "sign-off");
  expect(row.n).toBe(2);
  expect(row.figure.perWeek).toBeCloseTo((2 * 7) / 30, 6);
  expect(row.figure.usdPerSignoff).toBeCloseTo(4, 6);
  expect(row.figure.minutesPerSignoff).toBeCloseTo(10, 6);
  expect(row.figure.changesRate).toBe(0.5);
});

test("window counters ignore rows read only for the baseline", () => {
  const tenDaysBefore = "2026-11-02T10:00:00.000Z";
  const its = { iterations: [{ type: "advisor_message", model: "claude-fable-5-2", ...usage() }] };
  project("s1", [prompt(tenDaysBefore), step([], { ts: tenDaysBefore, usage: usage(its) })]);
  expect(report("--until", UNTIL, "7").advisor.mainCalls).toBe(0);
  expect(report("--until", UNTIL, "30").advisor.mainCalls).toBe(1);
});

test("an unparsed first review is unknown and stays out of the sheet kill rate", () => {
  put(join(home, ".local/state/jev/route.jsonl"), [outcome({ reviews: 1, firstReview: "unparsed", sheet: true }), { kind: "outcome", reviews: 1 }]);
  const { firstTimeRight, routeRowsWithoutTs } = report("--until", UNTIL, "30");
  expect(firstTimeRight).toEqual({ clean: 0, notClean: 0, unknown: 1 });
  expect(routeRowsWithoutTs).toBe(1);
  const kill = report("triggers", "--until", UNTIL).find((r: { name: string }) => r.name === "sheet kill rule");
  expect(kill.n).toBe(0);
});

test("ab splits reviewed edit requests by session effort from the start date", () => {
  reviewedRequest("s1", "REVIEW: clean", true, "high");
  reviewedRequest("s2", "REVIEW: clean", false, "medium");
  reviewedRequest("s3", "REVIEW: clean", false, "medium");
  expect(report("ab", "--until", UNTIL, "--from", "2026-11-13").a.reviewed).toBe(0);
  const { a, b, harmStop } = report("ab", "--until", UNTIL, "--from", "2026-11-01");
  expect(a.reviewed).toBe(1);
  expect(b.reviewed).toBe(2);
  expect(a.reworkRate).toBe(1);
  expect(b.reworkRate).toBe(0);
  expect(harmStop).toBe(false);
});
