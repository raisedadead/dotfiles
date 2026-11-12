import { afterEach, beforeEach, expect, test } from "bun:test";
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const SCRIPT = resolve(import.meta.dir, "../../dot_claude/skills/cmd-refresh-plugins/scripts/executable_refresh_plugins.sh");

let home: string;
let bin: string;
let sha: string;

const stub = (name: string, body: string) => {
  writeFileSync(join(bin, name), `#!/usr/bin/env bash\n${body}\n`);
  chmodSync(join(bin, name), 0o755);
};

const ghReturning = (runs: string) =>
  stub(
    "gh",
    `touch "$HOME/gh-called"
commit=""; expr=""
while [[ $# -gt 0 ]]; do
  case "$1" in --commit) commit="$2"; shift ;; --jq) expr="$2"; shift ;; esac
  shift
done
[[ "$commit" == "${sha}" ]] || { jq -r "$expr" <<< '[]'; exit 0; }
jq -r "$expr" <<< '${runs}'`,
  );

const run = (mode: string) => {
  const proc = Bun.spawnSync(["bash", SCRIPT, mode], {
    env: { PATH: `${bin}:${process.env.PATH ?? ""}`, HOME: home },
  });
  return { code: proc.exitCode, out: proc.stdout.toString(), err: proc.stderr.toString() };
};

const git = (...args: string[]) =>
  Bun.spawnSync(["git", "-c", "user.name=t", "-c", "user.email=t@t", ...args], { env: { PATH: process.env.PATH ?? "", HOME: home } })
    .stdout.toString()
    .trim();

beforeEach(() => {
  home = realpathSync(mkdtempSync(join(tmpdir(), "refresh-ci-")));
  bin = join(home, "bin");
  mkdirSync(bin, { recursive: true });
  mkdirSync(join(home, ".claude", "plugins", "cache"), { recursive: true });
  writeFileSync(join(home, ".claude", "plugins", "installed_plugins.json"), JSON.stringify({ plugins: {} }));
  const clone = join(home, ".claude", "plugins", "marketplaces", "raisedadead-plugins");
  mkdirSync(clone, { recursive: true });
  git("-C", clone, "init", "-q");
  git("-C", clone, "commit", "-q", "--allow-empty", "-m", "c");
  sha = git("-C", clone, "rev-parse", "HEAD");
  stub("claude", "exit 0");
});

afterEach(() => {
  rmSync(home, { recursive: true, force: true });
});

const success = '{"status":"completed","conclusion":"success"}';
const running = '{"status":"in_progress","conclusion":""}';

const seedInstalls = () => {
  const claudeDir = join(home, ".claude");
  const cache = join(claudeDir, "plugins", "cache");
  const mineInstall = join(cache, "raisedadead-plugins", "mine-plugin", "1.0.0");
  const otherInstall = join(cache, "other-market", "other-plugin", "1.0.0");
  mkdirSync(mineInstall, { recursive: true });
  mkdirSync(otherInstall, { recursive: true });
  writeFileSync(
    join(claudeDir, "plugins", "installed_plugins.json"),
    JSON.stringify({
      plugins: {
        "mine-plugin@raisedadead-plugins": [{ installPath: mineInstall, version: "1.0.0", gitCommitSha: "a".repeat(40) }],
        "other-plugin@other-market": [{ installPath: otherInstall, version: "1.0.0" }],
      },
    }),
  );
  writeFileSync(join(claudeDir, "settings.json"), JSON.stringify({ enabledPlugins: { "mine-plugin@raisedadead-plugins": true } }));
  const manifestDir = join(claudeDir, "plugins", "marketplaces", "raisedadead-plugins", ".claude-plugin");
  mkdirSync(manifestDir, { recursive: true });
  writeFileSync(
    join(manifestDir, "marketplace.json"),
    JSON.stringify({ plugins: [{ name: "mine-plugin", source: { source: "github", repo: "x/y", sha: "b".repeat(40) } }] }),
  );
  stub("claude", 'printf \'%s\\n\' "$*" >> "$HOME/claude-calls"\nexit 0');
};

const claudeCalls = () => readFileSync(join(home, "claude-calls"), "utf8").split("\n").filter(Boolean);

test("mine exits 1 before any update while a run on the clone's commit is unfinished", () => {
  ghReturning(`[${success},${running}]`);
  const r = run("mine");
  expect(r.code).toBe(1);
  expect(r.out).not.toContain("UPDATE");
  expect(r.err).toContain(sha);
});

test("all exits 1 but updates only third-party plugins while a run on the clone's commit is unfinished", () => {
  seedInstalls();
  ghReturning(`[${success},${running}]`);
  const r = run("all");
  expect(r.code).toBe(1);
  expect(r.out).toContain("UPDATE");
  expect(r.err).toContain(sha);
  const calls = claudeCalls();
  expect(calls).toContain("plugin update other-plugin@other-market --scope user");
  expect(calls.filter((call) => call.includes("@raisedadead-plugins"))).toEqual([]);
});

test("a commit with no CI run yet counts as not green", () => {
  ghReturning("[]");
  const r = run("mine");
  expect(r.code).toBe(1);
  expect(r.out).not.toContain("UPDATE");
});

test("a failing gh exits 1 and names the failed check, not CI", () => {
  stub("gh", 'echo "gh: not logged in" >&2; exit 1');
  const r = run("mine");
  expect(r.code).toBe(1);
  expect(r.err).toContain("gh: not logged in");
  expect(r.out).not.toContain("UPDATE");
});

test("mine updates once every run on the clone's commit succeeded", () => {
  ghReturning(`[${success}]`);
  const r = run("mine");
  expect(r.code).toBe(0);
  expect(r.out).toContain("UPDATE");
});

test("report never asks CI", () => {
  stub("gh", 'touch "$HOME/gh-called"; exit 1');
  const r = run("report");
  expect(r.code).toBe(0);
  expect(existsSync(join(home, "gh-called"))).toBe(false);
});
