import { afterEach, beforeEach, expect, test } from "bun:test";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, utimesSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";

const WS = resolve(import.meta.dir, "../../exact_dot_bin/executable_ws");
const DAY = 86_400_000;

let base: string;
let home: string;
let repo: string;

const env = () => ({
  PATH: process.env.PATH ?? "",
  HOME: home,
  XDG_CONFIG_HOME: join(home, ".config"),
  GIT_CONFIG_GLOBAL: "/dev/null",
  GIT_CONFIG_NOSYSTEM: "1",
});

const run = (cwd: string, ...args: string[]) => {
  const proc = Bun.spawnSync(["bun", WS, ...args], { cwd, env: env() });
  return { code: proc.exitCode, out: proc.stdout.toString(), err: proc.stderr.toString() };
};

const git = (cwd: string, ...args: string[]) => {
  const proc = Bun.spawnSync(["git", ...args], { cwd, env: env() });
  if (proc.exitCode !== 0) throw new Error(proc.stderr.toString());
};

const put = (path: string, text = "", ageDays = 0) => {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, text);
  const at = new Date(Date.now() - ageDays * DAY);
  utimesSync(path, at, at);
};

const start = (root: string) => readFileSync(join(root, ".scratchpad", "START.md"), "utf8");

beforeEach(() => {
  base = realpathSync(mkdtempSync(join(tmpdir(), "ws-")));
  home = join(base, "home");
  repo = join(base, "repo");
  mkdirSync(home);
  mkdirSync(join(repo, "src"), { recursive: true });
  git(repo, "init", "-q");
  put(join(repo, ".gitignore"), ".scratchpad/\n");
});

afterEach(() => rmSync(base, { recursive: true, force: true }));

test("in a repo that ignores .scratchpad, START.md goes to the repo top level", () => {
  const r = run(join(repo, "src"));
  expect(r.code).toBe(0);
  expect(existsSync(join(repo, ".scratchpad", "START.md"))).toBe(true);
  expect(r.out).toContain(join(repo, ".scratchpad", "START.md"));
});

test("in a repo that does not ignore .scratchpad, ws uses ~/.scratchpad and says why", () => {
  rmSync(join(repo, ".gitignore"));
  const r = run(repo);
  expect(r.code).toBe(0);
  expect(existsSync(join(repo, ".scratchpad"))).toBe(false);
  expect(existsSync(join(home, ".scratchpad", "START.md"))).toBe(true);
  expect(r.out).toContain("not git-ignored");
});

test("outside a repo, ws uses ~/.scratchpad and says why", () => {
  const outside = join(base, "plain");
  mkdirSync(outside);
  const r = run(outside);
  expect(r.code).toBe(0);
  expect(existsSync(join(home, ".scratchpad", "START.md"))).toBe(true);
  expect(r.out).toContain("not in a git repo");
});

test("START.md links INDEX.md and dossier/LATER.md only when they exist", () => {
  put(join(repo, ".scratchpad", "INDEX.md"), "# index\n");
  run(repo);
  expect(start(repo)).toContain("[INDEX.md](INDEX.md)");
  expect(start(repo)).not.toContain("LATER.md");
  put(join(repo, ".scratchpad", "dossier", "LATER.md"), "# later\n");
  run(repo);
  expect(start(repo)).toContain("[dossier/LATER.md](dossier/LATER.md)");
});

test("START.md lists each open handoff", () => {
  put(join(repo, ".scratchpad", "handoff", "2026-11-08-jev.md"), "# jev\n");
  const r = run(repo);
  expect(start(repo)).toContain("[handoff/2026-11-08-jev.md](handoff/2026-11-08-jev.md)");
  expect(r.out).toContain("handoff/2026-11-08-jev.md");
});

test("START.md shows only the open rows of OPEN-WORK.md", () => {
  const rows = [
    "| id | item | state | owner | home | source |",
    "|----|------|-------|-------|------|--------|",
    "| O1 | Fix `a | b` parsing | open | agent | here | x |",
    "| O2 | Shipped thing | done | agent | here | x |",
    "| O3 | Dropped thing | dropped | operator | here | x |",
    "| O4 | Moved thing | moved | agent | there | x |",
    "| O5 | Half thing | partial | agent | here | x |",
  ];
  put(join(repo, ".scratchpad", "OPEN-WORK.md"), `# Open work\n\n${rows.join("\n")}\n`);
  const r = run(repo);
  const text = start(repo);
  expect(text).toContain("O1");
  expect(text).toContain("Fix `a | b` parsing");
  expect(text).toContain("O5");
  for (const closed of ["O2", "O3", "O4"]) expect(text).not.toContain(closed);
  expect(r.out).toContain("open work rows: 2");
});

test("a tmp folder is idle when its newest file is 14 or more days old", () => {
  put(join(repo, ".scratchpad", "tmp", "old", "a.md"), "", 20);
  put(join(repo, ".scratchpad", "tmp", "old", "deep", "b.md"), "", 15);
  put(join(repo, ".scratchpad", "tmp", "fresh", "a.md"), "", 20);
  put(join(repo, ".scratchpad", "tmp", "fresh", "deep", "b.md"), "", 2);
  const fresh = join(repo, ".scratchpad", "tmp", "fresh");
  const old = new Date(Date.now() - 30 * DAY);
  utimesSync(fresh, old, old);
  const r = run(repo);
  expect(start(repo)).toContain("tmp/old");
  expect(start(repo)).not.toContain("tmp/fresh");
  expect(r.out).toContain("ws tidy");
});

test("START.md flags a top-level name outside the layout", () => {
  for (const name of ["INDEX.md", "OPEN-WORK.md", "handoff/x.md", "tmp/a/x.md", "research/a.md", "plans/a.md", "_archive/a.md", "dossier/a.md", ".cache/a"]) {
    put(join(repo, ".scratchpad", name), "");
  }
  put(join(repo, ".scratchpad", "HANDOFF-old.md"), "");
  const r = run(repo);
  expect(start(repo)).toContain("HANDOFF-old.md");
  for (const allowed of ["research", "plans", ".cache"]) expect(start(repo)).not.toContain(`\`${allowed}\``);
  expect(r.out).toContain("HANDOFF-old.md");
});

test("the printed summary is at most 10 lines", () => {
  for (let i = 0; i < 15; i++) put(join(repo, ".scratchpad", "handoff", `2026-11-0${i % 9}-h${i}.md`), "");
  for (let i = 0; i < 15; i++) put(join(repo, ".scratchpad", `loose-${i}.md`), "");
  const r = run(repo);
  expect(r.out.trimEnd().split("\n").length).toBeLessThanOrEqual(10);
});

test("START.md says it is rebuilt by ws and not edited by hand", () => {
  run(repo);
  expect(start(repo)).toContain("Do not edit");
});
