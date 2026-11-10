import { afterEach, beforeEach, expect, test } from "bun:test";
import { chmodSync, linkSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { ASK_WRITE, PRIVATE_APPEND } from "../../dot_claude/mods/rig/src/private-log";

let root = "";

beforeEach(() => {
  root = mkdtempSync(join(tmpdir(), "jev-log-"));
});

afterEach(() => {
  rmSync(root, { recursive: true, force: true });
});

const mode = (path: string): number => lstatSync(path).mode & 0o777;

const decision = (path: string, text: string): number =>
  Bun.spawnSync(["sh", "-c", PRIVATE_APPEND, "sh", path], { stdin: Buffer.from(text), timeout: 5000 }).exitCode ?? -1;

const ask = (path: string, line: string): number =>
  Bun.spawnSync(["sh", "-c", ASK_WRITE, "sh", path, line], { timeout: 5000 }).exitCode ?? -1;

function seed(path: string, text: string): string {
  writeFileSync(path, text);
  chmodSync(path, 0o644);
  return path;
}

function openFolder(): string {
  const dir = join(root, "jev");
  mkdirSync(dir);
  chmodSync(dir, 0o755);
  seed(join(dir, "decisions.jsonl"), "old\n");
  return dir;
}

test("a decision write makes an open folder and log private and keeps the old lines", () => {
  const dir = openFolder();
  expect(decision(join(dir, "decisions.jsonl"), "new\n")).toBe(0);
  expect(mode(dir)).toBe(0o700);
  expect(mode(join(dir, "decisions.jsonl"))).toBe(0o600);
  expect(readFileSync(join(dir, "decisions.jsonl"), "utf8")).toBe("old\nnew\n");
});

test("an ask write makes an open folder and an open log private", () => {
  const dir = openFolder();
  const log = seed(join(dir, "asks.jsonl"), "old\n");
  expect(ask(log, '{"a":1}')).toBe(0);
  expect(mode(dir)).toBe(0o700);
  expect(mode(log)).toBe(0o600);
  expect(readFileSync(log, "utf8")).toBe('old\n{"a":1}\n');
});

test("a missing folder and log are created private", () => {
  const log = join(root, "new/jev/decisions.jsonl");
  expect(decision(log, "x\n")).toBe(0);
  expect(mode(join(root, "new/jev"))).toBe(0o700);
  expect(mode(log)).toBe(0o600);
});

test("neither write goes through a symlink or a hard link at the log path", () => {
  const dir = openFolder();
  const target = seed(join(root, "target"), "kept\n");
  symlinkSync(target, join(dir, "soft.jsonl"));
  linkSync(target, join(dir, "hard.jsonl"));
  for (const name of ["soft.jsonl", "hard.jsonl"]) {
    expect(decision(join(dir, name), "bad\n")).not.toBe(0);
    expect(ask(join(dir, name), "bad")).not.toBe(0);
  }
  expect(readFileSync(target, "utf8")).toBe("kept\n");
  expect(mode(target)).toBe(0o644);
});

test("a write to a log path that is not a regular file fails at once", () => {
  const dir = openFolder();
  const fifo = join(dir, "fifo.jsonl");
  expect(Bun.spawnSync(["mkfifo", fifo]).exitCode).toBe(0);
  expect(decision(fifo, "bad\n")).not.toBe(0);
  expect(ask(fifo, "bad")).not.toBe(0);
});
