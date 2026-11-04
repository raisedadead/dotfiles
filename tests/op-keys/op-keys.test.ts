import { afterEach, beforeEach, expect, test } from "bun:test";
import { chmodSync, copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { existsSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const PERSONAL = "my.1password.com";
const WORK = "freecodecamp.1password.com";
const ROOT = resolve(import.meta.dir, "../..");
const DESKTOP_ERROR =
  "[ERROR] 2026/11/04 08:50:45 connecting to desktop app: 1Password CLI couldn't connect\n";

let dir: string;
let state: string;
let tool: string;

function item(title: string, vault: string, id: string, category = "API_CREDENTIAL") {
  return { id, title, category, vault: { id: `v-${vault}`, name: vault }, version: 1 };
}

function listFor(account: string, items: object[]) {
  writeFileSync(join(state, `${account}.list.json`), JSON.stringify(items));
}

function failFor(account: string, text: string) {
  writeFileSync(join(state, `${account}.err`), text);
}

function hangFor(account: string) {
  writeFileSync(join(state, `${account}.hang`), "");
}

function opCalls() {
  const log = join(state, "argv.log");
  return existsSync(log) ? readFileSync(log, "utf8") : "";
}

async function run(args: string[], timeoutMs = "2000") {
  const proc = Bun.spawn([tool, ...args], {
    env: {
      ...process.env,
      PATH: `${join(dir, "bin")}:${process.env.PATH}`,
      FAKE_OP_STATE: state,
      OP_KEYS_TIMEOUT_MS: timeoutMs,
    },
    stdin: "ignore",
    stdout: "pipe",
    stderr: "pipe",
  });
  const [stdout, stderr, code] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
    proc.exited,
  ]);
  return { stdout, stderr, code };
}

beforeEach(() => {
  dir = mkdtempSync(join(tmpdir(), "op-keys-"));
  state = join(dir, "state");
  mkdirSync(state);
  mkdirSync(join(dir, "bin"));
  tool = join(dir, "bin", "op-keys");
  copyFileSync(join(ROOT, "exact_dot_bin/executable_op-keys"), tool);
  chmodSync(tool, 0o755);
  copyFileSync(join(import.meta.dir, "fake-op.sh"), join(dir, "bin", "op"));
  chmodSync(join(dir, "bin", "op"), 0o755);
  listFor(PERSONAL, []);
  listFor(WORK, []);
});

afterEach(() => {
  rmSync(dir, { recursive: true, force: true });
});

test("find prints each match from both accounts, matching every word in any case", async () => {
  listFor(PERSONAL, [item("R2 Backup Token", "Infra", "p1"), item("Backup Disk", "Home", "p2")]);
  listFor(WORK, [item("r2-backup-tfstate", "Service-Automation", "w1", "SERVER")]);

  const { stdout, code } = await run(["find", "r2", "BACKUP"]);

  expect(code).toBe(0);
  expect(stdout.trimEnd().split("\n")).toEqual([
    "account\tvault\tcategory\ttitle\tid",
    `${PERSONAL}\tInfra\tAPI_CREDENTIAL\tR2 Backup Token\tp1`,
    `${WORK}\tService-Automation\tSERVER\tr2-backup-tfstate\tw1`,
  ]);
});

test("find says so when no item matches", async () => {
  listFor(PERSONAL, [item("Backup Disk", "Home", "p2")]);

  const { stdout, code } = await run(["find", "nothing-like-this"]);

  expect(code).toBe(0);
  expect(stdout).toContain("no item matches");
});

test("find reports a failing account apart from zero hits, and exits 1", async () => {
  failFor(WORK, DESKTOP_ERROR);
  listFor(PERSONAL, [item("Backup Disk", "Home", "p2")]);

  const { stdout, stderr, code } = await run(["find", "nothing-like-this"]);

  expect(code).toBe(1);
  expect(stderr).toContain(`${WORK}: ${DESKTOP_ERROR.trimEnd()}`);
  expect(stdout).not.toContain("no item matches");
});

test("find still prints the hits of the account that answered", async () => {
  failFor(WORK, DESKTOP_ERROR);
  listFor(PERSONAL, [item("Backup Disk", "Home", "p2")]);

  const { stdout, code } = await run(["find", "backup"]);

  expect(code).toBe(1);
  expect(stdout).toContain(`${PERSONAL}\tHome\tAPI_CREDENTIAL\tBackup Disk\tp2`);
});

test("find asks both accounts at once, so two waits cost one time limit", async () => {
  hangFor(PERSONAL);
  hangFor(WORK);

  const started = performance.now();
  const { stdout, stderr, code } = await run(["find", "backup"], "500");
  const elapsed = performance.now() - started;

  expect(code).toBe(1);
  expect(stderr).toContain(`${PERSONAL}: 1Password is waiting for approval`);
  expect(stderr).toContain(`${WORK}: 1Password is waiting for approval`);
  expect(stdout).not.toContain("no item matches");
  expect(elapsed).toBeLessThan(950);
});

test("fields prints names and references, and never a value", async () => {
  const concealed = "example-value-do-not-print";
  writeFileSync(
    join(state, `${PERSONAL}.get.json`),
    JSON.stringify({
      id: "p1",
      fields: [
        {
          id: "credential",
          type: "CONCEALED",
          label: "credential",
          value: concealed,
          reference: "op://Infra/R2/credential",
        },
        { id: "username", type: "STRING", label: "username", reference: "op://Infra/R2/username" },
        {
          id: "x",
          type: "CONCEALED",
          label: "Secret Access Key",
          value: concealed,
          section: { id: "s1", label: "Keys" },
          reference: "op://Infra/R2/Keys/Secret Access Key",
        },
      ],
    }),
  );

  const { stdout, stderr, code } = await run([
    "fields", "--account", PERSONAL, "--vault", "Infra", "R2",
  ]);

  expect(code).toBe(0);
  expect(stdout.trimEnd().split("\n")).toEqual([
    "section\tlabel\ttype\tvalue\treference",
    "-\tcredential\tCONCEALED\tset\top://Infra/R2/credential",
    "-\tusername\tSTRING\tempty\top://Infra/R2/username",
    "Keys\tSecret Access Key\tCONCEALED\tset\top://Infra/R2/Keys/Secret Access Key",
  ]);
  expect(stdout + stderr).not.toContain(concealed);
  expect(opCalls()).toContain(`item get R2 --account ${PERSONAL} --format json --vault Infra`);
});

test("fields reports a failure from op and exits 1", async () => {
  failFor(PERSONAL, "[ERROR] 2026/11/04 10:47:50 account is not signed in\n");

  const { stderr, code } = await run(["fields", "--account", PERSONAL, "R2"]);

  expect(code).toBe(1);
  expect(stderr).toContain("account is not signed in");
});

test("fields stops at the time limit and names the approval", async () => {
  hangFor(PERSONAL);

  const { stderr, code } = await run(["fields", "--account", PERSONAL, "R2"], "300");

  expect(code).toBe(1);
  expect(stderr).toContain("1Password is waiting for approval");
});

test.each([
  ["an unknown flag", ["fields", "--account", PERSONAL, "--password", "placeholder", "R2"]],
  ["a missing account", ["fields", "R2"]],
  ["a missing item", ["fields", "--account", PERSONAL]],
  ["find with no words", ["find"]],
  ["an unknown flag on find", ["find", "--password", "placeholder", "R2"]],
  ["an unknown command", ["read", "R2"]],
])("%s prints usage, exits 64 and never calls op", async (_name, args) => {
  const { stderr, code } = await run(args as string[]);

  expect(code).toBe(64);
  expect(stderr).toContain("usage:");
  expect(opCalls()).toBe("");
});
