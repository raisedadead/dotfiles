import { chmodSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import type { Subprocess } from "bun";

export const SCRIPT = resolve(import.meta.dir, "../../dot_claude/skills/cmd-refresh-plugins/scripts/executable_refresh_plugins.ts");

export type Fixture = { home: string; bin: string; claude: string; plugins: string; cache: string; tmp: string };
export type Result = { code: number | null; out: string; err: string };

const children: Subprocess[] = [];

export const stub = ({ bin }: Fixture, name: string, body: string): void => {
  writeFileSync(join(bin, name), `#!/usr/bin/env bash\n${body}\n`);
  chmodSync(join(bin, name), 0o755);
};

export const CLAUDE_LOG = 'printf \'%s|%s\\n\' "$PWD" "$*" >> "$HOME/claude-calls"';

export const fixture = (): Fixture => {
  const home = realpathSync(mkdtempSync(join(tmpdir(), "refresh-fx-")));
  const claude = join(home, ".claude");
  const plugins = join(claude, "plugins");
  const fx = { home, bin: join(home, "bin"), claude, plugins, cache: join(plugins, "cache"), tmp: join(home, "tmp") };
  for (const dir of [fx.bin, fx.cache, fx.tmp]) mkdirSync(dir, { recursive: true });
  stub(fx, "claude", `${CLAUDE_LOG}\nexit 0`);
  stub(fx, "gh", 'echo "gh stub" >&2; exit 1');
  stub(fx, "tmux", "exit 1");
  return fx;
};

export const cleanup = ({ home }: Fixture): void => {
  for (const child of children.splice(0)) child.kill();
  rmSync(home, { recursive: true, force: true });
};

export const runWith = ({ home, bin, tmp }: Fixture, env: Record<string, string>, ...args: string[]): Result => {
  const proc = Bun.spawnSync([SCRIPT, ...args], {
    cwd: home,
    env: { PATH: `${bin}:${process.env.PATH ?? ""}`, HOME: home, TMPDIR: tmp, ...env },
  });
  return { code: proc.exitCode, out: proc.stdout.toString(), err: proc.stderr.toString() };
};

export const run = (fx: Fixture, ...args: string[]): Result => runWith(fx, {}, ...args);

export const MINE = "raisedadead-plugins";

export const green = (fx: Fixture, verdict = "true"): string => {
  const clone = join(fx.plugins, "marketplaces", MINE);
  mkdirSync(clone, { recursive: true });
  const git = (...args: string[]) =>
    Bun.spawnSync(["git", "-c", "user.name=t", "-c", "user.email=t@t", "-C", clone, ...args], { env: { PATH: process.env.PATH ?? "", HOME: fx.home } })
      .stdout.toString()
      .trim();
  git("init", "-q");
  git("commit", "-q", "--allow-empty", "-m", "c");
  stub(fx, "gh", `echo ${verdict}`);
  return git("rev-parse", "HEAD");
};

export const section = (out: string, from: string, to: string): string => out.slice(out.indexOf(`${from}\n`), out.indexOf(`${to}\n`));

export const sized = (out: string): string => out.replace(/^ {2}cache size: +\d[\d.]*[BKMGT]$/m, "  cache size: SIZE");

export const json = (path: string, data: unknown): void => {
  mkdirSync(resolve(path, ".."), { recursive: true });
  writeFileSync(path, JSON.stringify(data));
};

export const installs = ({ plugins }: Fixture, records: Record<string, unknown>): void =>
  json(join(plugins, "installed_plugins.json"), { version: 2, plugins: records });

export const version = ({ cache }: Fixture, market: string, name: string, ver: string): string => {
  const dir = join(cache, market, name, ver);
  mkdirSync(dir, { recursive: true });
  return dir;
};

export const marketplace = ({ plugins }: Fixture, market: string, entries: unknown): string => {
  const root = join(plugins, "marketplaces", market);
  json(join(root, ".claude-plugin", "marketplace.json"), { name: market, plugins: entries });
  return root;
};

export const live = (): number => {
  const child = Bun.spawn(["sleep", "60"]);
  children.push(child);
  return child.pid;
};

export const dead = (): number => Bun.spawnSync(["true"]).pid;

export const mark = (dir: string, ...pids: number[]): void => {
  mkdirSync(join(dir, ".in_use"), { recursive: true });
  for (const pid of pids) writeFileSync(join(dir, ".in_use", String(pid)), "");
};

export const started = (pid: number): string =>
  Bun.spawnSync(["ps", "-o", "lstart=", "-p", String(pid)], { env: { PATH: process.env.PATH ?? "", TZ: "UTC" } })
    .stdout.toString()
    .trim()
    .split(/\s+/)
    .join(" ");

export const session = ({ claude }: Fixture, pid: number, record: Record<string, unknown>): void =>
  json(join(claude, "sessions", `${pid}.json`), { procStart: started(pid), ...record });

export const calls = ({ home }: Fixture): string[] => {
  try {
    return readFileSync(join(home, "claude-calls"), "utf8").split("\n").filter(Boolean);
  } catch {
    return [];
  }
};
