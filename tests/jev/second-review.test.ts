import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const FILE = resolve(import.meta.dir, "../../dot_agents/jev/second-review.json");
const TOPICS = ["deploy", "guard", "secret"];

type Topic = { label: string; instructions: string; criteria: string };
type Questions = {
  model: string;
  timeoutMs: number;
  enforce: boolean;
  bands: { note: number; block: number };
  topics: Record<string, Topic>;
};

const load = (): Questions => JSON.parse(readFileSync(FILE, "utf8"));

test("pins a versioned Jev model, not an alias", () => {
  expect(load().model).toMatch(/^jev-\d+\.\d+\.\d+$/);
});

test("bands order the note line below the block line", () => {
  const { note, block } = load().bands;
  expect(note).toBeGreaterThan(0);
  expect(block).toBeGreaterThan(note);
  expect(block).toBeLessThanOrEqual(1);
});

test("timeout is a positive whole number of milliseconds and enforce is a flag", () => {
  const q = load();
  expect(Number.isInteger(q.timeoutMs) && q.timeoutMs > 0).toBe(true);
  expect(typeof q.enforce).toBe("boolean");
});

test("asks exactly the guard, secret and deploy topics, each about one path", () => {
  const { topics } = load();
  expect(Object.keys(topics).sort()).toEqual(TOPICS);
  for (const topic of Object.values(topics)) {
    expect(topic.label.trim()).not.toBe("");
    expect(topic.instructions.split("{path}").length).toBe(2);
    expect(topic.criteria.trim()).not.toBe("");
  }
});
