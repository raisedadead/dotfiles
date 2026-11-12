import { afterEach, beforeEach, expect, test } from "bun:test";
import { existsSync, mkdirSync, mkdtempSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { Subprocess } from "bun";
import { SCRIPT } from "./harness";

let home: string;
let cache: string;
let holder: Subprocess | undefined;

const run = (mode: string) => {
  const proc = Bun.spawnSync([SCRIPT, mode], { env: { PATH: process.env.PATH ?? "", HOME: home } });
  return { code: proc.exitCode, out: proc.stdout.toString(), err: proc.stderr.toString() };
};

const started = (pid: number) =>
  Bun.spawnSync(["ps", "-o", "lstart=", "-p", String(pid)], { env: { PATH: process.env.PATH ?? "", TZ: "UTC" } })
    .stdout.toString()
    .trim()
    .split(/\s+/)
    .join(" ");

const install = () => {
  mkdirSync(join(cache, "new"), { recursive: true });
  const plugins = { plugins: { "p@m": [{ installPath: join(cache, "new"), version: "new" }] } };
  writeFileSync(join(home, ".claude", "plugins", "installed_plugins.json"), JSON.stringify(plugins));
};

const hold = (record: Record<string, string>) => {
  holder = Bun.spawn(["sleep", "30"]);
  const pid = holder.pid;
  mkdirSync(join(cache, "old", ".in_use"), { recursive: true });
  writeFileSync(join(cache, "old", ".in_use", String(pid)), "");
  mkdirSync(join(home, ".claude", "sessions"), { recursive: true });
  writeFileSync(join(home, ".claude", "sessions", `${pid}.json`), JSON.stringify({ ...record, procStart: started(pid) }));
  return pid;
};

beforeEach(() => {
  home = realpathSync(mkdtempSync(join(tmpdir(), "refresh-")));
  cache = join(home, ".claude", "plugins", "cache", "m", "p");
  mkdirSync(cache, { recursive: true });
});

afterEach(() => {
  holder?.kill();
  holder = undefined;
  rmSync(home, { recursive: true, force: true });
});

test("a background agent that holds an old copy is told to respawn by its job id", () => {
  install();
  hold({ kind: "bg", version: "1.0.0", name: "infra", jobId: "d57a7211" });
  const r = run("report");
  expect(r.out).toContain("claude respawn d57a7211");
  expect(r.out).not.toContain("terminal that shows the job");
});

test("a session that started before the current copy existed is told why and to reload", async () => {
  hold({ kind: "interactive", version: "1.0.0", name: "infra-6b" });
  await Bun.sleep(1100);
  install();
  const r = run("report");
  expect(r.out).toContain("started before the current copy");
  expect(r.out).toContain("/reload-plugins");
});

test("burst deletes copies no live process holds, and does not update or reinstall", () => {
  install();
  mkdirSync(join(cache, "old"), { recursive: true });
  const r = run("burst");
  expect(r.code).toBe(0);
  expect(existsSync(join(cache, "old"))).toBe(false);
  expect(existsSync(join(cache, "new"))).toBe(true);
  expect(r.out).not.toContain("UPDATE");
  expect(r.out).not.toContain("FORCE");
});
