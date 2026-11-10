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

test("from a linked worktree, START.md goes to the main checkout", () => {
  git(repo, "-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false", "commit", "-q", "--allow-empty", "-m", "init");
  const linked = join(base, "linked");
  git(repo, "worktree", "add", "-q", linked);
  const r = run(linked);
  expect(r.code).toBe(0);
  expect(existsSync(join(repo, ".scratchpad", "START.md"))).toBe(true);
  expect(existsSync(join(linked, ".scratchpad"))).toBe(false);
});

test("a pattern that ignores only some files does not count as ignoring .scratchpad", () => {
  put(join(repo, ".gitignore"), "*.md\n");
  const r = run(repo);
  expect(existsSync(join(repo, ".scratchpad"))).toBe(false);
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
    "| O6 | Odd ` tick | done | agent | here | x |",
  ];
  put(join(repo, ".scratchpad", "OPEN-WORK.md"), `# Open work\n\n${rows.join("\n")}\n`);
  const r = run(repo);
  const text = start(repo);
  expect(text).toContain("O1");
  expect(text).toContain("Fix `a | b` parsing");
  expect(text).toContain("O5");
  for (const closed of ["O2", "O3", "O4", "O6"]) expect(text).not.toContain(closed);
  expect(r.out).toContain("open work rows: 2");
});

test("a tmp folder is idle when its newest file is 14 or more days old", () => {
  put(join(repo, ".scratchpad", "tmp", "old", "a.md"), "", 20);
  put(join(repo, ".scratchpad", "tmp", "old", "deep", "b.md"), "", 15);
  put(join(repo, ".scratchpad", "tmp", "fresh", "a.md"), "", 20);
  put(join(repo, ".scratchpad", "tmp", "fresh", "deep", "b.md"), "", 2);
  mkdirSync(join(repo, ".scratchpad", "tmp", "old", "empty"));
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

const today = () => new Date().toISOString().slice(0, 10);

test("ws tidy moves idle tmp folders to _archive/tmp and logs each move", () => {
  const pad = join(repo, ".scratchpad");
  put(join(pad, "tmp", "old", "a.md"), "kept", 20);
  put(join(pad, "tmp", "fresh", "a.md"), "", 1);
  const r = run(repo, "tidy");
  expect(r.code).toBe(0);
  expect(readFileSync(join(pad, "_archive", "tmp", "old", "a.md"), "utf8")).toBe("kept");
  expect(existsSync(join(pad, "tmp", "old"))).toBe(false);
  expect(existsSync(join(pad, "tmp", "fresh", "a.md"))).toBe(true);
  expect(readFileSync(join(pad, "_archive", `MOVED-${today()}.txt`), "utf8")).toContain("tmp/old -> _archive/tmp/old");
  expect(start(repo)).not.toContain("tmp/old`");
});

test("ws tidy refuses a name that already exists in the archive", () => {
  const pad = join(repo, ".scratchpad");
  put(join(pad, "tmp", "old", "a.md"), "new", 20);
  put(join(pad, "_archive", "tmp", "old", "a.md"), "archived");
  const r = run(repo, "tidy");
  expect(r.code).toBe(1);
  expect(readFileSync(join(pad, "tmp", "old", "a.md"), "utf8")).toBe("new");
  expect(readFileSync(join(pad, "_archive", "tmp", "old", "a.md"), "utf8")).toBe("archived");
  expect(r.err).toContain("tmp/old");
});

test("a held lock refuses ws tidy and moves nothing", () => {
  const pad = join(repo, ".scratchpad");
  put(join(pad, "tmp", "old", "a.md"), "", 20);
  put(join(pad, ".ws-tidy.lock"), String(process.pid));
  const r = run(repo, "tidy");
  expect(r.code).toBe(1);
  expect(existsSync(join(pad, "tmp", "old", "a.md"))).toBe(true);
  expect(r.err).toContain("lock");
});

test("an empty lock file that is still young counts as held", () => {
  const pad = join(repo, ".scratchpad");
  put(join(pad, "tmp", "old", "a.md"), "", 20);
  put(join(pad, ".ws-tidy.lock"), "");
  expect(run(repo, "tidy").code).toBe(1);
  expect(existsSync(join(pad, "tmp", "old", "a.md"))).toBe(true);
});

test("ws tidy runs in a project that has no .scratchpad yet", () => {
  rmSync(join(repo, ".scratchpad"), { recursive: true, force: true });
  const r = run(repo, "tidy");
  expect(r.code).toBe(0);
  expect(existsSync(join(repo, ".scratchpad", "START.md"))).toBe(true);
});

test("ws tidy takes over a lock whose process is gone", () => {
  const pad = join(repo, ".scratchpad");
  put(join(pad, "tmp", "old", "a.md"), "", 20);
  const gone = Bun.spawnSync(["true"]).pid;
  put(join(pad, ".ws-tidy.lock"), String(gone));
  const r = run(repo, "tidy");
  expect(r.code).toBe(0);
  expect(existsSync(join(pad, "_archive", "tmp", "old", "a.md"))).toBe(true);
  expect(existsSync(join(pad, ".ws-tidy.lock"))).toBe(false);
});

const commit = (cwd: string, message: string) =>
  git(cwd, "-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false", "commit", "-q", "--allow-empty", "-m", message);

const section = (out: string, name: string) => {
  const from = out.indexOf(`## ${name}\n`);
  if (from < 0) return "";
  const rest = out.slice(from + name.length + 4);
  const next = rest.indexOf("\n## ");
  return next < 0 ? rest : rest.slice(0, next);
};

test("ws brief prints six sections, each with None when empty, and writes no file", () => {
  rmSync(join(repo, ".scratchpad"), { recursive: true, force: true });
  const r = run(repo, "brief");
  expect(r.code).toBe(0);
  const headings = r.out.split("\n").filter(line => line.startsWith("## "));
  expect(headings).toEqual(["## Handoffs", "## Due", "## Agent work", "## Operator work", "## Live dossiers", "## Git"]);
  for (const name of ["Handoffs", "Due", "Agent work", "Operator work", "Live dossiers"]) expect(section(r.out, name)).toContain("- None.");
  expect(existsSync(join(repo, ".scratchpad"))).toBe(false);
});

test("ws brief lists each handoff by its full path", () => {
  put(join(repo, ".scratchpad", "handoff", "2026-11-10-a.md"), "# a\n");
  const r = run(repo, "brief");
  expect(section(r.out, "Handoffs")).toContain(join(repo, ".scratchpad", "handoff", "2026-11-10-a.md"));
});

test("ws brief shows dated items that are due today or earlier, and hides later ones", () => {
  const pad = join(repo, ".scratchpad");
  put(join(pad, "dossier", "LATER.md"), "# Carried work\n- w/T1 · Past check · due 2020-01-01\n- w/T2 · Future check · due 2999-01-01\n");
  const rows = [
    "| id | item | state | owner | home | source |",
    "|----|------|-------|-------|------|--------|",
    "| O1 | Wait for it | deferred — until 2020-02-02 | agent | here | x |",
    "| O2 | Not yet | deferred — until 2999-02-02 | agent | here | x |",
    "| O3 | Closed and old | done | agent | due 2020-03-03 | x |",
  ];
  put(join(pad, "OPEN-WORK.md"), `${rows.join("\n")}\n`);
  const due = section(run(repo, "brief").out, "Due");
  expect(due).toContain("Past check");
  expect(due).toContain("O1 (agent, deferred");
  for (const hidden of ["Future check", "O2", "O3"]) expect(due).not.toContain(hidden);
});

test("ws brief splits open rows by owner", () => {
  const rows = [
    "| id | item | state | owner | home | source |",
    "|----|------|-------|-------|------|--------|",
    "| O1 | Agent thing | open | agent | here | x |",
    "| O2 | Operator thing | open | operator | here | x |",
    "| O3 | Shipped | done | agent | here | x |",
  ];
  put(join(repo, ".scratchpad", "OPEN-WORK.md"), `${rows.join("\n")}\n`);
  const r = run(repo, "brief");
  expect(section(r.out, "Agent work")).toContain("O1 (open): Agent thing");
  expect(section(r.out, "Agent work")).not.toContain("O2");
  expect(section(r.out, "Operator work")).toContain("O2 (open): Operator thing");
  expect(r.out).not.toContain("O3");
});

test("ws brief lists only live dossiers from INDEX.md", () => {
  const rows = [
    "| date | slug | state | T | B | mtime | §Z |",
    "|------|------|-------|---|---|-------|-----|",
    "| 2026-11-10 | now | live | 1/4 | 0 | x | — |",
    "| 2026-11-09 | old | done | 4/4 | 0 | x | complete |",
  ];
  put(join(repo, ".scratchpad", "INDEX.md"), `# index\n\n${rows.join("\n")}\n`);
  const live = section(run(repo, "brief").out, "Live dossiers");
  expect(live).toContain("dossier/2026-11-10-now/DOSSIER.md");
  expect(live).toContain("1/4");
  expect(live).not.toContain("2026-11-09-old");
});

test("ws brief shows uncommitted and unpushed state for the repo and each submodule", () => {
  const lib = join(base, "lib");
  mkdirSync(lib);
  git(lib, "init", "-q");
  commit(lib, "lib");
  git(repo, "add", ".gitignore");
  commit(repo, "init");
  git(repo, "-c", "protocol.file.allow=always", "submodule", "add", "-q", lib, "sub");
  commit(repo, "add sub");
  commit(join(repo, "sub"), "local");
  put(join(repo, "sub", "new.txt"), "x");
  put(join(repo, "a.txt"), "x");
  const gitState = section(run(repo, "brief").out, "Git");
  expect(gitState).toMatch(/`\.` \S+: 2 uncommitted, no upstream/);
  expect(gitState).toMatch(/`sub` \S+: 1 uncommitted, 1 unpushed/);
  git(join(repo, "sub"), "checkout", "-q", "--detach");
  commit(join(repo, "sub"), "detached");
  expect(section(run(repo, "brief").out, "Git")).toContain("`sub` (detached): 1 uncommitted, 2 unpushed");
});

test("START.md says it is rebuilt by ws and not edited by hand", () => {
  run(repo);
  expect(start(repo)).toContain("Do not edit");
});
