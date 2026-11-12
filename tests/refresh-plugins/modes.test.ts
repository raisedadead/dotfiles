import { afterEach, beforeEach, expect, test } from "bun:test";
import { existsSync } from "node:fs";
import { basename, join } from "node:path";
import { CLAUDE_LOG, calls, cleanup, type Fixture, fixture, green, installs, MINE, marketplace, run, SCRIPT, section, sized, stub, version } from "./harness";

let fx: Fixture;

beforeEach(() => {
  fx = fixture();
});

afterEach(() => {
  cleanup(fx);
});

const USAGE = `${basename(SCRIPT).replace(/^executable_/, "")} [all|mine|burst|report]

  all     (default) update every plugin, burst, then report
  mine    update the raisedadead-plugins plugins only, burst every plugin,
          then report
  burst   burst every plugin, then report; no update and no reinstall
  report  read-only: installed version, cached versions, which are reclaimable,
          and whether the install still matches what the marketplace ships

all and mine first fetch the raisedadead-plugins marketplace, then check that
every CI run on the commit that clone now holds is completed with success. A
gh error counts as not green. mine exits 1 before any plugin update unless it
is green. all prints REFUSING, skips the raisedadead-plugins plugins, updates
the rest, bursts, reports, then exits 1.

Update = marketplace update + plugin update, then a forced reinstall of any
install that drifted from its marketplace source. Burst = delete reclaimable
cached versions.

Reclaimable means: not the current install, AND every live PID holding an
.in_use marker on it also holds one on the current version. A PID on the old
version but NOT on current is a session still running that build - keep it.

Drift means: the marketplace ships something the install does not have.
\`claude plugin update\` cannot fix it when the plugin declares a \`version\` key,
because the cache directory is named from that key - an unbumped version is the
same directory, so the update is a no-op and every report reads CURRENT. The
only lever is uninstall + install, which the update step does for you.
`;

const EMPTY_RUN = [
  "UPDATE",
  "FORCE",
  "  forced 0 reinstall(s), 0 rolled back, 0 left uninstalled",
  "BURST",
  "  removed 0 version dir(s), pruned 0 dead marker(s)",
  "REPORT",
  "  reclaimable version dirs: 0",
  "  cache size: SIZE",
  "",
].join("\n");

const NOT_GREEN = (refused: string, sha: string) =>
  `REFUSING ${refused}: CI on ${sha} is not green yet; every run must succeed. See: gh run list --repo raisedadead/claude-code-plugins --commit ${sha}\n`;
const WHOLE = "the whole mine run (no update, burst or report)";
const PART = `the ${MINE} update (${MINE} plugins skipped, others still updated)`;
const SKIPPED = `The ${MINE} plugins were skipped because their CI is not green.\n`;

test.each(["-h", "--help", "help"])("%s prints the usage and exits 0", (flag) => {
  const r = run(fx, flag);
  expect(r).toEqual({ code: 0, out: USAGE, err: "" });
  expect(calls(fx)).toEqual([]);
});

test("an unknown mode prints the usage and exits 2", () => {
  expect(run(fx, "nope")).toEqual({ code: 2, out: USAGE, err: "" });
  expect(calls(fx)).toEqual([]);
});

test.each([[[]], [[""]]])("no mode (%p) runs all: CI check, update, force, burst, report", (args) => {
  green(fx);
  const r = run(fx, ...args);
  expect(r.code).toBe(0);
  expect(r.err).toBe("");
  expect(sized(r.out)).toBe(EMPTY_RUN);
  expect(calls(fx)).toEqual([`${fx.home}|plugin marketplace update ${MINE}`]);
});

test("mine refuses the whole run on red CI and prints nothing on stdout", () => {
  const sha = green(fx, "false");
  const r = run(fx, "mine");
  expect(r).toEqual({ code: 1, out: "", err: NOT_GREEN(WHOLE, sha) });
});

test("all on red CI names the skip twice on stderr and exits 1 after the full run", () => {
  const sha = green(fx, "false");
  const r = run(fx, "all");
  expect(r.code).toBe(1);
  expect(sized(r.out)).toBe(EMPTY_RUN);
  expect(r.err).toBe(NOT_GREEN(PART, sha) + SKIPPED);
});

test("a missing marketplace clone refuses with the clone path", () => {
  const r = run(fx, "mine");
  const clone = join(fx.plugins, "marketplaces", MINE);
  expect(r).toEqual({ code: 1, out: "", err: `REFUSING ${WHOLE}: no ${MINE} marketplace clone at ${clone} to check against CI\n` });
});

test("a gh failure is quoted in the refusal", () => {
  const sha = green(fx);
  stub(fx, "gh", 'echo "gh: not logged in" >&2; exit 4');
  const r = run(fx, "all");
  expect(r.code).toBe(1);
  expect(r.err).toBe(`REFUSING ${PART}: the CI check for ${sha} could not run: gh: not logged in\n${SKIPPED}`);
});

test("gh output other than true is not green", () => {
  const sha = green(fx);
  stub(fx, "gh", 'echo "true"; echo "warning: something" >&2');
  const r = run(fx, "mine");
  expect(r).toEqual({ code: 1, out: "", err: NOT_GREEN(WHOLE, sha) });
});

test("a failed fetch of the raisedadead-plugins marketplace warns on stderr and goes on", () => {
  green(fx);
  stub(fx, "claude", `${CLAUDE_LOG}\n[[ "$*" == "plugin marketplace update ${MINE}" ]] && exit 1\nexit 0`);
  const r = run(fx, "all");
  expect(r.code).toBe(0);
  expect(r.err).toBe(`  WARN marketplace update failed: ${MINE}\n`);
  expect(sized(r.out)).toBe(EMPTY_RUN);
});

test("mine with no raisedadead-plugins install warns that none comes from it", () => {
  green(fx);
  const r = run(fx, "mine");
  expect(r.code).toBe(0);
  expect(section(r.out, "UPDATE", "FORCE")).toBe(`UPDATE\n  WARN no installed plugin comes from ${MINE}\n`);
});

test("mine updates only raisedadead-plugins plugins but bursts every plugin", () => {
  green(fx);
  const mine = version(fx, MINE, "own", "1.0.0");
  const other = version(fx, "m", "other", "2.0.0");
  version(fx, "m", "other", "1.0.0");
  marketplace(fx, MINE, [{ name: "own", source: { sha: "a".repeat(40) } }]);
  installs(fx, {
    [`own@${MINE}`]: [{ installPath: mine, version: "1.0.0", gitCommitSha: "a".repeat(40) }],
    "other@m": [{ installPath: other, version: "2.0.0" }],
  });

  const r = run(fx, "mine");

  expect(r.code).toBe(0);
  expect(r.err).toBe("");
  expect(section(r.out, "UPDATE", "BURST")).toBe(
    ["UPDATE", `  marketplace: ${MINE}`, `  plugin: own@${MINE} (was 1.0.0)`, "FORCE", "  forced 0 reinstall(s), 0 rolled back, 0 left uninstalled", ""].join("\n"),
  );
  expect(section(r.out, "BURST", "REPORT")).toBe("BURST\n    reclaimed other/1.0.0\n  removed 1 version dir(s), pruned 0 dead marker(s)\n");
  expect(existsSync(join(fx.cache, "m", "other", "1.0.0"))).toBe(false);
  expect(calls(fx)).toEqual([`${fx.home}|plugin marketplace update ${MINE}`, `${fx.home}|plugin update own@${MINE} --scope user`]);
});
