import { afterEach, beforeEach, expect, test } from "bun:test";
import { chmodSync, existsSync, mkdirSync, readdirSync, symlinkSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { cleanup, dead, type Fixture, fixture, installs, json, live, marketplace, mark, run, runWith, session, sized, stub, version } from "./harness";

let fx: Fixture;

beforeEach(() => {
  fx = fixture();
});

afterEach(() => {
  cleanup(fx);
});

const row = (name: string, label: string) => `      ${name.padEnd(12)} ${label}`;
const UNVERIFIED = "CURRENT, unverified — the marketplace names no source to compare against";

const ship = (dir: string, files: Record<string, string>) => {
  for (const [name, body] of Object.entries(files)) {
    mkdirSync(join(dir, name, ".."), { recursive: true });
    writeFileSync(join(dir, name), body);
  }
};

test("report labels each cached version, names its holder, and changes nothing", () => {
  const current = version(fx, "m", "p", "2.0.0");
  version(fx, "m", "p", "1.0.0");
  const held = version(fx, "m", "p", "1.5.0");
  const stale = version(fx, "m", "p", "1.8.0");
  const holder = live();
  const gone = dead();
  mark(held, holder);
  mark(stale, gone);
  ship(current, { "a.txt": "x", "__pycache__/z.pyc": "runtime" });
  const root = marketplace(fx, "m", [{ name: "p", source: "./plugins/p" }]);
  ship(join(root, "plugins", "p"), { "a.txt": "x" });
  const outside = join(fx.home, "elsewhere", "q", "1.0.0");
  mkdirSync(outside, { recursive: true });
  installs(fx, { "p@m": [{ installPath: current, version: "2.0.0" }], "q@m": [{ installPath: outside, version: "1.0.0" }] });

  const r = run(fx, "report");

  expect(r.code).toBe(0);
  expect(r.err).toBe("");
  expect(sized(r.out)).toBe(
    [
      "REPORT",
      "  p@m -> 2.0.0",
      row("1.0.0", "reclaimable"),
      row("1.5.0", "IN USE by a session not yet on current"),
      `        held by ${holder}: no session record; reload it or let it exit`,
      row("1.8.0", "reclaimable"),
      row("2.0.0", "CURRENT"),
      "  q@m -> 1.0.0 (install path outside the cache — not managed here)",
      "  reclaimable version dirs: 2",
      "  cache size: SIZE",
      "",
    ].join("\n"),
  );
  expect(existsSync(join(stale, ".in_use", String(gone)))).toBe(true);
  expect(readdirSync(join(fx.cache, "m", "p")).sort()).toEqual(["1.0.0", "1.5.0", "1.8.0", "2.0.0"]);
});

test("report compares each install with what its marketplace ships", () => {
  const sha = "abcdef1234567890abcdef1234567890abcdef12";
  const names = ["short", "stale", "nosha", "same", "diff", "missing", "link", "unread", "gitdir", "nodir", "none", "located", "listed"];
  const dirs = Object.fromEntries(names.map((name) => [name, version(fx, name === "located" ? "dm" : name === "listed" ? "lm" : "m", name, "1.0.0")]));
  const root = marketplace(fx, "m", [
    { name: "short", source: { source: "github", repo: "x/y", sha: "abcdef1" } },
    { name: "stale", source: { source: "github", repo: "x/y", sha: "b".repeat(40) } },
    { name: "nosha", source: { source: "github", repo: "x/y", sha: "c".repeat(40) } },
    ...["same", "diff", "missing", "link", "unread", "gitdir", "nodir"].map((name) => ({ name, source: `./plugins/${name}` })),
  ]);
  const ships = (name: string) => join(root, "plugins", name);
  ship(ships("same"), { "a.txt": "x", "sub/b.txt": "y" });
  ship(dirs.same, { "a.txt": "x", "sub/b.txt": "y", ".DS_Store": "z" });
  ship(ships("diff"), { "a.txt": "new" });
  ship(dirs.diff, { "a.txt": "old" });
  ship(ships("missing"), { "only-shipped.txt": "x" });
  mkdirSync(ships("link"), { recursive: true });
  symlinkSync("target-one", join(ships("link"), "l"));
  symlinkSync("target-two", join(dirs.link, "l"));
  ship(ships("unread"), { "secret.txt": "x" });
  ship(dirs.unread, { "secret.txt": "x" });
  chmodSync(join(ships("unread"), "secret.txt"), 0o000);
  ship(ships("gitdir"), { "a.txt": "x", ".git/config": "c" });
  ship(dirs.gitdir, { "a.txt": "x" });
  const elsewhere = join(fx.home, "dir-market");
  json(join(elsewhere, ".claude-plugin", "marketplace.json"), { plugins: [{ name: "located", source: { sha: "d".repeat(40) } }] });
  json(join(fx.plugins, "known_marketplaces.json"), { dm: { installLocation: elsewhere } });
  json(join(fx.plugins, "marketplaces", "lm", ".claude-plugin", "marketplace.json"), [{ name: "listed", source: { sha: "e".repeat(40) } }]);
  installs(
    fx,
    Object.fromEntries(
      names.map((name) => [
        `${name}@${name === "located" ? "dm" : name === "listed" ? "lm" : "m"}`,
        [{ installPath: dirs[name], version: "1.0.0", ...(name === "nosha" ? {} : { gitCommitSha: name === "stale" || name === "located" || name === "listed" ? "a".repeat(40) : sha }) }],
      ]),
    ),
  );

  const r = run(fx, "report");

  expect(r.code).toBe(0);
  const labels = [
    "CURRENT",
    "CURRENT but STALE — install sha aaaaaaaaaaaa, marketplace pins bbbbbbbbbbbb",
    "CURRENT",
    "CURRENT",
    `CURRENT but STALE — differs from what ${ships("diff")} ships, first at a.txt`,
    `CURRENT but STALE — differs from what ${ships("missing")} ships, first at only-shipped.txt`,
    `CURRENT but STALE — differs from what ${ships("link")} ships, first at l`,
    `CURRENT, unverified — 1 file(s) under ${ships("unread")} could not be read, so the comparison is incomplete`,
    "CURRENT",
    "CURRENT",
    UNVERIFIED,
    "CURRENT but STALE — install sha aaaaaaaaaaaa, marketplace pins dddddddddddd",
    "CURRENT but STALE — install sha aaaaaaaaaaaa, marketplace pins eeeeeeeeeeee",
  ];
  const market = (name: string) => (name === "located" ? "dm" : name === "listed" ? "lm" : "m");
  expect(sized(r.out)).toBe(
    [
      "REPORT",
      ...names.flatMap((name, i) => [`  ${name}@${market(name)} -> 1.0.0`, row("1.0.0", labels[i])]),
      "  reclaimable version dirs: 0",
      "  cache size: SIZE",
      "",
    ].join("\n"),
  );
});

test("report skips install records it cannot use and falls back to version or sha for the directory name", () => {
  version(fx, "m", "fallback", "3.0.0");
  version(fx, "m", "shaonly", "cccccccccccc");
  installs(fx, {
    "bad@m": "not a list",
    "obj@m": ["a string"],
    "nover@m": [{}],
    "sep@m": [{ installPath: join(fx.cache, "m", "sep", "1.0.0"), projectPath: "a\nb" }],
    "fallback@m": [{ version: "3.0.0/" }],
    "shaonly@m": [{ gitCommitSha: "c".repeat(40) }],
    "ondisk@m": [{ installPath: join(fx.cache, "m", "ondisk", "9.9.9") }],
  });

  const r = run(fx, "report");

  expect(r.code).toBe(0);
  expect(r.err).toBe(
    [
      "skipping bad@m: entries is not a list",
      "skipping obj@m: install record is not an object",
      "skipping nover@m: no usable install directory name",
      "skipping sep@m: a field holds a separator or newline",
      "",
    ].join("\n"),
  );
  expect(sized(r.out)).toBe(
    [
      "REPORT",
      "  fallback@m -> 3.0.0",
      row("3.0.0", UNVERIFIED),
      "  shaonly@m -> cccccccccccc",
      row("cccccccccccc", UNVERIFIED),
      "  ondisk@m -> 9.9.9 (install path outside the cache — not managed here)",
      "  reclaimable version dirs: 0",
      "  cache size: SIZE",
      "",
    ].join("\n"),
  );
});

test("report lists version dirs in the shell's glob order for the locale", () => {
  const current = version(fx, "m", "p", "v1");
  for (const name of ["1.0.0-beta", "1.0.0_rc", "V2", "_x"]) version(fx, "m", "p", name);
  installs(fx, { "p@m": [{ installPath: current, version: "v1" }] });

  const r = runWith(fx, { LC_ALL: "en_US.UTF-8" }, "report");

  expect(r.code).toBe(0);
  expect(sized(r.out)).toBe(
    [
      "REPORT",
      "  p@m -> v1",
      row("_x", "reclaimable"),
      row("1.0.0_rc", "reclaimable"),
      row("1.0.0-beta", "reclaimable"),
      row("v1", UNVERIFIED),
      row("V2", "reclaimable"),
      "  reclaimable version dirs: 4",
      "  cache size: SIZE",
      "",
    ].join("\n"),
  );
});

test("report with no install record prints an empty report", () => {
  const r = run(fx, "report");
  expect(r.code).toBe(0);
  expect(r.err).toBe("");
  expect(sized(r.out)).toBe("REPORT\n  reclaimable version dirs: 0\n  cache size: SIZE\n");
});

test("each held by line names the holder kind and the fix for it", async () => {
  const current = version(fx, "m", "p", "9.0.0");
  await Bun.sleep(1100);
  const pids = Array.from({ length: 7 }, () => live());
  const [none, reused, nojob, shown, parked, plain, both] = pids;
  const terminal = live();
  pids.forEach((pid, i) => mark(version(fx, "m", "p", `v${i + 1}`), pid));
  mark(current, both);
  session(fx, reused, { kind: "interactive", version: "1.0.0", name: "n2", procStart: "Mon Jan  1 00:00:00 2001" });
  session(fx, nojob, { kind: "bg", version: "1.0.0", name: "n3\u0007​" });
  session(fx, shown, { kind: "bg", version: "1.0.0", name: "n4", jobId: "j4" });
  session(fx, terminal, { kind: "interactive", version: "1.0.0", name: "t4", parkedJobId: "j4" });
  session(fx, parked, { kind: "interactive", version: "1.0.0", name: "n5", parkedJobId: "j5" });
  session(fx, plain, { kind: "interactive", version: "1.0.0", name: "n6" });
  session(fx, both, { kind: "interactive", version: "1.0.0", name: "n7" });
  installs(fx, { "p@m": [{ installPath: current, version: "9.0.0" }] });

  const r = run(fx, "report");

  const lines = (name: string, text: string) => [row(name, "IN USE by a session not yet on current"), `        held by ${text}`];
  expect(r.code).toBe(0);
  expect(r.err).toBe("");
  expect(sized(r.out)).toBe(
    [
      "REPORT",
      "  p@m -> 9.0.0",
      row("9.0.0", UNVERIFIED),
      ...lines("v1", `${none}: no session record; reload it or let it exit`),
      ...lines("v2", `${reused}: its session record belongs to an earlier process with this PID; check what it is with ps -p ${reused}`),
      ...lines("v3", `${nojob} (bg 1.0.0, n3): background job with no job id; stop it, or let it exit`),
      ...lines("v4", `${shown} (bg 1.0.0, n4): background job j4. Type /reload-plugins in the terminal that shows the job, or run claude respawn j4`),
      ...lines("v5", `${parked} (interactive 1.0.0, n5): the terminal of background job j5. /reload-plugins in the job does not move it; it releases this version when it exits`),
      ...lines("v6", `${plain} (interactive 1.0.0, n6): run /reload-plugins in it, or let it exit`),
      row("v7", "reclaimable"),
      "  reclaimable version dirs: 1",
      "  cache size: SIZE",
      "",
    ].join("\n"),
  );
});

test("a holder in a tmux pane is named by its pane", async () => {
  const current = version(fx, "m", "p", "2.0.0");
  const old = version(fx, "m", "p", "1.0.0");
  const pty = "import os, pty, sys\npid, fd = pty.fork()\nif pid == 0:\n    os.execvp('sleep', ['sleep', '60'])\nprint(pid, flush=True)\nos.waitpid(pid, 0)";
  const wrapper = Bun.spawn(["python3", "-c", pty], { stdout: "pipe" });
  try {
    const reader = wrapper.stdout.getReader();
    const pid = Number(new TextDecoder().decode((await reader.read()).value).trim());
    process.kill(pid, 0);
    const tty = Bun.spawnSync(["ps", "-o", "tty=", "-p", String(pid)]).stdout.toString().trim();
    expect(tty).not.toBe("??");
    stub(fx, "tmux", `printf '/dev/ttys999 other:0.0\\n/dev/${tty} work:2.1\\n'`);
    mark(old, pid);
    session(fx, pid, { kind: "interactive", version: "1.0.0", name: "paned" });
    installs(fx, { "p@m": [{ installPath: current, version: "2.0.0" }] });

    const r = run(fx, "report");

    expect(r.out).toContain(`        held by ${pid} (interactive 1.0.0, paned, tmux work:2.1): `);
  } finally {
    Bun.spawnSync(["pkill", "-P", String(wrapper.pid)]);
    wrapper.kill();
  }
});
