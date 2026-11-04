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

const ENTER = "\r";
const CTRL_C = "\x03";
const CONFIRM = "Create this item?";
const NEW_FLAGS = ["--account", PERSONAL, "--vault", "Infra", "--title", "Example"];
const TYPED = "typed-example-value";
const NO_ANSWER = "1Password may be waiting for approval";
const ACCOUNT_ID = "0123456789abcdef0123456789abcdef";
const RIGHT_TO_LEFT_OVERRIDE = String.fromCodePoint(0x202e);
const REORDERING_TITLE = `abc${RIGHT_TO_LEFT_OVERRIDE}def`;
const HOSTILE_NOTES = `a\u009b31m${RIGHT_TO_LEFT_OVERRIDE}b`;
const ENDPOINT = `https://${ACCOUNT_ID}.r2.cloudflarestorage.com`;
const templateField = (id: string, type = "STRING") => ({ id, type, label: id, value: "" });
const LOGIN_TEMPLATE = {
  title: "",
  category: "LOGIN",
  fields: [
    templateField("username"),
    templateField("password", "CONCEALED"),
    templateField("notesPlain"),
  ],
};
const API_TEMPLATE = {
  title: "",
  category: "API_CREDENTIAL",
  fields: [
    templateField("notesPlain"),
    templateField("username"),
    templateField("credential", "CONCEALED"),
    templateField("type", "MENU"),
    templateField("filename"),
    templateField("validFrom", "DATE"),
    templateField("expires", "DATE"),
    templateField("hostname"),
  ],
};

let dir: string;
let state: string;
let tool: string;

function toolEnv(timeoutMs: string) {
  return {
    ...process.env,
    PATH: `${join(dir, "bin")}:${process.env.PATH}`,
    FAKE_OP_STATE: state,
    OP_KEYS_TIMEOUT_MS: timeoutMs,
  };
}

async function drive(
  args: string[],
  steps: [string, string | { signal: "SIGTERM" }][],
  timeoutMs = "2000",
) {
  const decoder = new TextDecoder();
  let screen = "";
  let seenUpTo = 0;
  const proc = Bun.spawn([tool, ...args], {
    env: toolEnv(timeoutMs),
    terminal: {
      cols: 120,
      rows: 40,
      data(_terminal, data) {
        screen += decoder.decode(data);
      },
    },
  });
  for (const [prompt, keys] of steps) {
    const deadline = performance.now() + 4_000;
    while (screen.indexOf(prompt, seenUpTo) < 0) {
      if (performance.now() > deadline) {
        proc.kill();
        throw new Error(`no prompt "${prompt}" on screen:\n${screen}`);
      }
      await Bun.sleep(10);
    }
    seenUpTo = screen.indexOf(prompt, seenUpTo) + prompt.length;
    if (typeof keys === "string") {
      proc.terminal!.write(keys);
    } else {
      proc.kill(keys.signal);
    }
  }
  const code = await proc.exited;
  await Bun.sleep(20);
  proc.terminal!.close();
  return { screen, code };
}

function created() {
  return JSON.parse(readFileSync(join(state, "created.json"), "utf8")) as {
    title: string;
    category: string;
    fields: { id?: string; label?: string; type: string; value: string }[];
  };
}

function createdValues() {
  return Object.fromEntries(created().fields.map(({ id, label, value }) => [label ?? id, value]));
}

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

async function run(args: string[], timeoutMs = "2000", cwd = dir) {
  const proc = Bun.spawn([tool, ...args], {
    cwd,
    env: toolEnv(timeoutMs),
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
  copyFileSync(join(ROOT, "exact_dot_bin/op-keys-prompts.js"), join(dir, "bin", "op-keys-prompts.js"));
  copyFileSync(join(import.meta.dir, "fake-op.sh"), join(dir, "bin", "op"));
  chmodSync(join(dir, "bin", "op"), 0o755);
  listFor(PERSONAL, []);
  listFor(WORK, []);
  writeFileSync(join(state, "template-Login.json"), JSON.stringify(LOGIN_TEMPLATE));
  writeFileSync(join(state, "template-API Credential.json"), JSON.stringify(API_TEMPLATE));
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
  expect(stderr).toContain(`${PERSONAL}: op did not answer in time; ${NO_ANSWER}`);
  expect(stderr).toContain(`${WORK}: op did not answer in time; ${NO_ANSWER}`);
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
  expect(stderr).toContain(NO_ANSWER);
});

test("a repo's bunfig.toml and .env do not reach the tool or op", async () => {
  const hostile = join(dir, "hostile");
  const marker = join(state, "preload-ran");
  mkdirSync(hostile);
  writeFileSync(join(hostile, "bunfig.toml"), 'preload = ["./planted.ts"]\n');
  writeFileSync(join(hostile, "planted.ts"), `await Bun.write(${JSON.stringify(marker)}, "ran");\n`);
  writeFileSync(join(hostile, ".env"), "OP_CONNECT_HOST=https://attacker.invalid\n");

  const { code } = await run(["find", "backup"], "2000", hostile);

  expect(code).toBe(0);
  expect(existsSync(marker)).toBe(false);
  expect(existsSync(join(state, "connect-host"))).toBe(false);
});

test.each([
  ["an unknown flag", ["fields", "--account", PERSONAL, "--password", "placeholder", "R2"]],
  ["a missing account", ["fields", "R2"]],
  ["a missing item", ["fields", "--account", PERSONAL]],
  ["find with no words", ["find"]],
  ["an unknown flag on find", ["find", "--password", "placeholder", "R2"]],
  ["an unknown command", ["read", "R2"]],
  ["a secret flag on new", ["new", "login", ...NEW_FLAGS, "--password", "placeholder"]],
  ["an unknown kind", ["new", "ssh", ...NEW_FLAGS]],
  ["a kind name inherited by every object", ["new", "constructor", ...NEW_FLAGS]],
  ["new with no title", ["new", "login", "--account", PERSONAL, "--vault", "Infra"]],
  ["r2 with no account ID", ["new", "r2", ...NEW_FLAGS]],
  ["an account ID on login", ["new", "login", ...NEW_FLAGS, "--account-id", ACCOUNT_ID]],
  ["an r2 account ID that is not 32 hex digits", ["new", "r2", ...NEW_FLAGS, "--account-id", "abc"]],
  ["a flag passed as the item after --", ["fields", "--account", PERSONAL, "--", "--reveal"]],
  [
    "a title that forges a summary line",
    ["new", "login", "--account", PERSONAL, "--vault", "Infra", "--title", "a\naccount: other"],
  ],
  [
    "a title that reorders itself on screen",
    ["new", "login", "--account", PERSONAL, "--vault", "Infra", "--title", REORDERING_TITLE],
  ],
])("%s prints usage, exits 64 and never calls op", async (_name, args) => {
  const { stderr, code } = await run(args as string[]);

  expect(code).toBe(64);
  expect(stderr).toContain("usage:");
  expect(opCalls()).toBe("");
});

test("new refuses without a terminal and never calls op", async () => {
  const { stderr, code } = await run(["new", "login", ...NEW_FLAGS]);

  expect(code).toBe(1);
  expect(stderr).toContain("needs a terminal");
  expect(opCalls()).toBe("");
});

test("new login sends the typed values on stdin only, with empty fields dropped", async () => {
  const { screen, code } = await drive(["new", "login", ...NEW_FLAGS], [
    ["username", `me${ENTER}`],
    ["password", `${TYPED}${ENTER}`],
    [CONFIRM, "y"],
  ]);

  expect(code).toBe(0);
  expect(created().title).toBe("Example");
  expect(created().category).toBe("LOGIN");
  expect(createdValues()).toEqual({ username: "me", password: TYPED });
  expect(opCalls()).toContain(
    `item create --account ${PERSONAL} --vault Infra --format json -`,
  );
  expect(opCalls()).not.toContain(TYPED);
  expect(screen).not.toContain(TYPED);
  expect(screen).toContain("created Example");
});

test("new api with no ID and with notes carries no unasked template field", async () => {
  const { code } = await drive(["new", "api", ...NEW_FLAGS, "--notes", "why it exists"], [
    ["credential", `${TYPED}${ENTER}`],
    ["ID (optional)", ENTER],
    [CONFIRM, "y"],
  ]);

  expect(code).toBe(0);
  expect(createdValues()).toEqual({ credential: TYPED, notesPlain: "why it exists" });
});

test("new api stores the optional ID as the username", async () => {
  const { code } = await drive(["new", "api", ...NEW_FLAGS], [
    ["credential", `${TYPED}${ENTER}`],
    ["ID (optional)", `id-1${ENTER}`],
    [CONFIRM, "y"],
  ]);

  expect(code).toBe(0);
  expect(createdValues()).toEqual({ credential: TYPED, username: "id-1" });
});

test("new r2 writes the custom fields and builds the endpoint from the account ID", async () => {
  const { screen, code } = await drive(["new", "r2", ...NEW_FLAGS, "--account-id", ACCOUNT_ID], [
    ["Access Key ID", `key-id-value${ENTER}`],
    ["Secret Access Key", `${TYPED}${ENTER}`],
    ["Token value (optional)", ENTER],
    [CONFIRM, "y"],
  ]);

  expect(code).toBe(0);
  expect(createdValues()).toEqual({
    "Access Key ID": "key-id-value",
    "Secret Access Key": TYPED,
    Endpoint: ENDPOINT,
  });
  expect(created().fields.map(({ type }) => type)).toEqual(["CONCEALED", "CONCEALED", "URL"]);
  expect(screen).not.toContain("key-id-value");
  expect(screen.slice(screen.indexOf("New item"), screen.lastIndexOf(CONFIRM))).toContain(ENDPOINT);
});

test("new shows the account, vault, title and field names before it asks", async () => {
  const { screen } = await drive(["new", "login", ...NEW_FLAGS, "--notes", "line one\nline two"], [
    ["username", `me${ENTER}`],
    ["password", `${TYPED}${ENTER}`],
    [CONFIRM, ENTER],
  ]);
  const summary = screen.slice(screen.indexOf("New item"), screen.lastIndexOf(CONFIRM));

  for (const name of [PERSONAL, "Infra", "Example", "username", "password"]) {
    expect(summary).toContain(name);
  }
  expect(summary).toContain('notes: "line one\\nline two"');
});

test("new shows notes with every terminal control character escaped", async () => {
  const { screen } = await drive(["new", "login", ...NEW_FLAGS, "--notes", HOSTILE_NOTES], [
    ["username", `me${ENTER}`],
    ["password", `${TYPED}${ENTER}`],
    [CONFIRM, ENTER],
  ]);

  expect(screen).toContain('notes: "a\\u009b31m\\u202eb"');
  expect(screen).not.toContain("\u009b");
  expect(screen).not.toContain(RIGHT_TO_LEFT_OVERRIDE);
});

test("new stops before any prompt when --notes has no field to go in", async () => {
  writeFileSync(
    join(state, "template-Login.json"),
    JSON.stringify({
      ...LOGIN_TEMPLATE,
      fields: [templateField("username"), templateField("password", "CONCEALED")],
    }),
  );

  const { screen, code } = await drive(["new", "login", ...NEW_FLAGS, "--notes", "kept"], []);

  expect(code).toBe(1);
  expect(screen).toContain("template has no notesPlain field");
  expect(opCalls()).not.toContain("item create");
});

test("new refuses an empty required value and accepts the retry", async () => {
  const { screen, code } = await drive(["new", "login", ...NEW_FLAGS], [
    ["username", `me${ENTER}`],
    ["password", ENTER],
    ["is required", `${TYPED}${ENTER}`],
    [CONFIRM, "y"],
  ]);

  expect(code).toBe(0);
  expect(screen).toContain("password is required");
  expect(createdValues().password).toBe(TYPED);
});

test("new stops before any prompt when the title exists in the vault", async () => {
  listFor(PERSONAL, [item("Example", "Infra", "p1")]);

  const { screen, code } = await drive(["new", "login", ...NEW_FLAGS], []);

  expect(code).toBe(1);
  expect(screen).toContain("already exists");
  expect(screen).not.toContain("username");
  expect(opCalls()).not.toContain("item create");
});

test("new stops before any prompt when 1Password does not answer", async () => {
  hangFor(PERSONAL);

  const { screen, code } = await drive(["new", "login", ...NEW_FLAGS], [], "300");

  expect(code).toBe(1);
  expect(screen).toContain(NO_ANSWER);
  expect(screen).not.toContain("username");
  expect(opCalls()).not.toContain("item create");
});

test("new stops before any prompt when a template lost a field it fills", async () => {
  writeFileSync(
    join(state, "template-Login.json"),
    JSON.stringify({ ...LOGIN_TEMPLATE, fields: [templateField("username")] }),
  );

  const { screen, code } = await drive(["new", "login", ...NEW_FLAGS], []);

  expect(code).toBe(1);
  expect(screen).toContain("template has no password field");
  expect(opCalls()).not.toContain("item create");
});

test("new creates nothing when the confirm is left at its default", async () => {
  const { screen, code } = await drive(["new", "login", ...NEW_FLAGS], [
    ["username", `me${ENTER}`],
    ["password", `${TYPED}${ENTER}`],
    [CONFIRM, ENTER],
  ]);

  expect(code).toBe(1);
  expect(screen).toContain("nothing created");
  expect(opCalls()).not.toContain("item create");
});

test("new creates nothing on Ctrl+C at a prompt", async () => {
  const { screen, code } = await drive(["new", "login", ...NEW_FLAGS], [
    ["username", CTRL_C],
  ]);

  expect(code).toBe(1);
  expect(screen).toContain("nothing created");
  expect(opCalls()).not.toContain("item create");
});

test("new puts no time limit on create, because the operator is in the popup", async () => {
  writeFileSync(join(state, "create.delay"), "");

  const { code } = await drive(["new", "login", ...NEW_FLAGS], [
    ["username", `me${ENTER}`],
    ["password", `${TYPED}${ENTER}`],
    [CONFIRM, "y"],
  ], "200");

  expect(code).toBe(0);
  expect(createdValues().password).toBe(TYPED);
});

test("new says the outcome is unknown when create is interrupted", async () => {
  writeFileSync(join(state, "create.hang"), "");

  const { screen, code } = await drive(["new", "login", ...NEW_FLAGS], [
    ["username", `me${ENTER}`],
    ["password", `${TYPED}${ENTER}`],
    [CONFIRM, "y"],
    ["creating the item", CTRL_C],
  ]);

  expect(code).toBe(130);
  expect(screen).toContain("outcome is unknown");
  expect(screen).toContain("op-keys find");
});

test("new says the outcome is unknown when create gets SIGTERM", async () => {
  writeFileSync(join(state, "create.hang"), "");

  const { screen, code } = await drive(["new", "login", ...NEW_FLAGS], [
    ["username", `me${ENTER}`],
    ["password", `${TYPED}${ENTER}`],
    [CONFIRM, "y"],
    ["creating the item", { signal: "SIGTERM" }],
  ]);

  expect(code).toBe(143);
  expect(screen).toContain("outcome is unknown");
});

test("new reports a failed create and exits 1", async () => {
  writeFileSync(join(state, "create.err"), "[ERROR] 2026/11/04 10:47:50 create refused\n");

  const { screen, code } = await drive(["new", "login", ...NEW_FLAGS], [
    ["username", `me${ENTER}`],
    ["password", `${TYPED}${ENTER}`],
    [CONFIRM, "y"],
  ]);

  expect(code).toBe(1);
  expect(screen).toContain("create refused");
  expect(screen).not.toContain("created Example");
});
