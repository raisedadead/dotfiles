import { afterEach, beforeEach, expect, test } from "bun:test";
import { existsSync, mkdirSync, readdirSync, symlinkSync } from "node:fs";
import { join } from "node:path";
import { calls, cleanup, dead, type Fixture, fixture, installs, live, mark, run, section, sized, version } from "./harness";

let fx: Fixture;

beforeEach(() => {
  fx = fixture();
});

afterEach(() => {
  cleanup(fx);
});

const row = (name: string, label: string) => `      ${name.padEnd(12)} ${label}`;

test("burst prunes dead markers, deletes unheld copies, keeps held ones, refuses what it cannot place, then reports", () => {
  const current = version(fx, "m", "p", "2.0.0");
  version(fx, "m", "p", "1.0.0");
  const held = version(fx, "m", "p", "1.5.0");
  const shared = version(fx, "m", "p", "1.6.0");
  const deadOnly = version(fx, "m", "p", "1.7.0");
  const [holder, mover] = [live(), live()];
  const [gone1, gone2, gone3] = [dead(), dead(), dead()];
  mark(current, gone1, mover);
  mark(held, holder, gone2);
  mark(shared, mover);
  mark(deadOnly, gone3);
  mkdirSync(join(fx.cache, "m", "gone"), { recursive: true });
  const outside = join(fx.home, "elsewhere", "out", "1.0.0");
  mkdirSync(outside, { recursive: true });
  installs(fx, {
    "p@m": [{ installPath: current, version: "2.0.0" }],
    "gone@m": [{ installPath: join(fx.cache, "m", "gone", "3.0.0"), version: "3.0.0" }],
    "out@m": [{ installPath: outside, version: "1.0.0" }],
  });

  const r = run(fx, "burst");

  expect(r.code).toBe(0);
  expect(r.err).toBe("");
  expect(sized(r.out)).toBe(
    [
      "BURST",
      "    reclaimed p/1.0.0",
      "    reclaimed p/1.6.0",
      "    reclaimed p/1.7.0",
      "    REFUSING gone: current install 3.0.0 is not in the cache",
      `    REFUSING out: install path resolves outside ${fx.cache}`,
      "  removed 3 version dir(s), pruned 3 dead marker(s)",
      "REPORT",
      "  p@m -> 2.0.0",
      row("1.5.0", "IN USE by a session not yet on current"),
      `        held by ${holder}: no session record; reload it or let it exit`,
      row("2.0.0", "CURRENT, unverified — the marketplace names no source to compare against"),
      "  gone@m -> 3.0.0",
      "  out@m -> 1.0.0 (install path outside the cache — not managed here)",
      "  reclaimable version dirs: 0",
      "  cache size: SIZE",
      "",
    ].join("\n"),
  );
  expect(readdirSync(join(fx.cache, "m", "p")).sort()).toEqual(["1.5.0", "2.0.0"]);
  expect(readdirSync(join(current, ".in_use"))).toEqual([String(mover)]);
  expect(readdirSync(join(held, ".in_use"))).toEqual([String(holder)]);
  expect(existsSync(outside)).toBe(true);
  expect(calls(fx)).toEqual([]);
});

test("burst never deletes inside the install when its path ends in /.", () => {
  const current = version(fx, "m", "p", "1.0.0");
  for (const sub of ["hooks", "skills"]) mkdirSync(join(current, sub));
  installs(fx, { "p@m": [{ installPath: `${current}/.`, version: "1.0.0" }] });

  const r = run(fx, "burst");

  expect(r.code).toBe(0);
  expect(readdirSync(current).sort()).toEqual(["hooks", "skills"]);
  expect(section(r.out, "BURST", "REPORT")).toBe("BURST\n  removed 0 version dir(s), pruned 0 dead marker(s)\n");
});

test("burst never deletes the installed version through a symlinked version dir", () => {
  const real = version(fx, "m", "p", "1.0.0");
  mkdirSync(join(real, "hooks"));
  symlinkSync("1.0.0", join(fx.cache, "m", "p", "live"));
  installs(fx, { "p@m": [{ installPath: join(fx.cache, "m", "p", "live"), version: "1.0.0" }] });

  const r = run(fx, "burst");

  expect(r.code).toBe(0);
  expect(readdirSync(real)).toEqual(["hooks"]);
  expect(section(r.out, "BURST", "REPORT")).toBe("BURST\n  removed 0 version dir(s), pruned 0 dead marker(s)\n");
});

test("burst keeps a version dir that holds the install, and the report says why", () => {
  const inner = join(version(fx, "m", "p", "old"), "inner");
  mkdirSync(join(inner, "hooks"), { recursive: true });
  symlinkSync("old/inner", join(fx.cache, "m", "p", "1.0.0"));
  installs(fx, { "p@m": [{ installPath: join(fx.cache, "m", "p", "1.0.0"), version: "1.0.0" }] });

  const r = run(fx, "burst");

  expect(r.code).toBe(0);
  expect(readdirSync(inner)).toEqual(["hooks"]);
  expect(sized(r.out)).toBe(
    [
      "BURST",
      "  removed 0 version dir(s), pruned 0 dead marker(s)",
      "REPORT",
      "  p@m -> 1.0.0",
      row("1.0.0", "CURRENT, unverified — the marketplace names no source to compare against"),
      row("old", "kept: overlaps the current install"),
      "  reclaimable version dirs: 0",
      "  cache size: SIZE",
      "",
    ].join("\n"),
  );
});

test("burst keeps every version dir that another scope of the same plugin still uses", () => {
  const user = version(fx, "m", "p", "1.0.0");
  const project = version(fx, "m", "p", "2.0.0");
  installs(fx, {
    "p@m": [
      { scope: "user", installPath: user, version: "1.0.0" },
      { scope: "project", projectPath: join(fx.home, "proj"), installPath: project, version: "2.0.0" },
    ],
  });

  const r = run(fx, "burst");

  expect(r.code).toBe(0);
  expect(r.out).not.toContain("reclaimed p/");
  expect(r.out).not.toContain("REFUSING");
  expect(section(r.out, "BURST", "REPORT")).toBe("BURST\n  removed 0 version dir(s), pruned 0 dead marker(s)\n");
  expect(existsSync(user)).toBe(true);
  expect(existsSync(project)).toBe(true);
});

test("burst on an empty install list removes nothing", () => {
  const r = run(fx, "burst");
  expect(r.code).toBe(0);
  expect(sized(r.out)).toBe("BURST\n  removed 0 version dir(s), pruned 0 dead marker(s)\nREPORT\n  reclaimable version dirs: 0\n  cache size: SIZE\n");
});
