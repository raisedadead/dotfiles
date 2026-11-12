import { afterAll, afterEach, beforeAll, beforeEach, expect, test } from "bun:test";
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";

const SCRIPT = process.env.SWITCHER_SCRIPT ?? resolve(import.meta.dir, "../../dot_config/tmux/scripts/executable_switcher");
const RUNNER = SCRIPT.endsWith(".sh") ? ["bash"] : ["bun", "--no-env-file", "--config=/dev/null"];
const REAL_TMUX = Bun.which("tmux") ?? "tmux";
const SOCKET = `switcher-test-${process.pid}`;

const DIM = "\x1b[38;2;147;153;178m";
const HI = "\x1b[38;2;137;180;250m";
const ACCENT = "\x1b[38;2;249;226;175m";
const SUB = "\x1b[38;2;166;173;200m";
const GREEN = "\x1b[38;2;166;227;161m";
const MAUVE = "\x1b[38;2;203;166;247m";
const RST = "\x1b[0m";
const ICON = {
  session: "\u{F018D}",
  project: "\u{F0770}",
  config: "\u{F0493}",
  zoxide: "\u{F02DA}",
  files: "\u{F0219}",
  text: "\u{F0284}",
  bookmark: "\u{F00C0}",
};
const COLORS = [
  "bg+:#313244,bg:#11111B,spinner:#F5E0DC,hl:#F38BA8,fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC",
  "marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8,selected-bg:#45475A,border:#6C7086,label:#CDD6F4",
].join(",");
const IGNORE = "node_modules|.git|__pycache__|.next|dist|build|.cache|.turbo|vendor";

let root: string;
let home: string;
let work: string;
let state: string;
let stubs: string;
let log: string;
let windows: string;
let zoxide: string;
let marks: string;

const env = (extra: Record<string, string> = {}): Record<string, string> => ({
  PATH: `${stubs}:${process.env.PATH ?? ""}`,
  HOME: home,
  XDG_STATE_HOME: state,
  LC_ALL: "en_US.UTF-8",
  SHELL: "/bin/sh",
  EDITOR: "/usr/bin/true",
  VISUAL: join(stubs, "visual"),
  SWT_LOG: log,
  SWT_WINDOWS: windows,
  SWT_ZOXIDE: zoxide,
  SWT_DIR: root,
  SWT_SOCKET: SOCKET,
  ...extra,
});

const run = (args: string[], extra: Record<string, string> = {}) => {
  const proc = Bun.spawnSync([...RUNNER, SCRIPT, ...args], { cwd: root, env: env(extra) });
  return { code: proc.exitCode, out: proc.stdout.toString(), err: proc.stderr.toString() };
};

const tmux = (...args: string[]) => Bun.spawnSync([REAL_TMUX, "-L", SOCKET, ...args], { env: env() }).stdout.toString().trim();

const put = (path: string, text: string | Uint8Array = "") => {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, text);
};

const stub = (name: string, body: string) => {
  const path = join(stubs, name);
  writeFileSync(path, `#!/bin/sh\n${body}\n`);
  chmodSync(path, 0o755);
};

const pad = (text: string, width: number) => text + " ".repeat(Math.max(0, width - Buffer.byteLength(text)));
const b64 = (text: string) => Buffer.from(text).toString("base64");
const keys = (out: string) => out.split("\n").filter(Boolean).map((line) => line.split("\t")[0]);
const actions = () => readFileSync(log, "utf8").split("\n").filter((line) => line && !line.startsWith("[list-windows]"));

const LOOK: Record<string, [string, string, string]> = {
  tmux: [ICON.session, "session", GREEN],
  parked: [ICON.session, "parked", DIM],
  proj: [ICON.project, "project", HI],
  conf: [ICON.config, "config", ACCENT],
  zox: [ICON.zoxide, "zoxide", MAUVE],
};

const row = (cat: string, target: string, path: string, marked = false, home_ = home) => {
  const [icon, label, color] = LOOK[cat];
  const name = cat === "tmux" || cat === "parked" ? target.split(":")[0] : path.slice(path.lastIndexOf("/") + 1);
  const short = path.startsWith(home_) ? `~${path.slice(home_.length)}` : path;
  const mark = marked ? `${ACCENT}${ICON.bookmark}${RST}  ` : "   ";
  return `${cat}|${target}|${path}\t${mark}${HI}${icon}  ${pad(name, 20)}${RST}\t${color}${pad(label, 7)}${RST}\t${DIM}${short}${RST}\n`;
};

const fileRow = (path: string, marked = false, home_ = home) => {
  const name = path.slice(path.lastIndexOf("/") + 1);
  const short = path === home_ || path.startsWith(`${home_}/`) ? `~${path.slice(home_.length)}` : path;
  const mark = marked ? `${ACCENT}${ICON.bookmark}${RST}  ` : "   ";
  return `search||${b64(path)}\t${mark}${HI}${ICON.files}  ${pad(name, 22)}${RST}\t${DIM}srch${RST}\t${DIM}${short}${RST}\n`;
};

const textRow = (path: string, line: number, text: string) =>
  `search|${line}|${b64(path)}\t${HI}${ICON.text}  ${path.slice(work.length + 1)}:${line}:${text}\n`;

const header = (active: string) => {
  const items: [string, string][] = [
    ["<C-a>", "All"],
    ["<C-t>", "Sessions"],
    ["<C-p>", "Projects"],
    ["<C-z>", "Zoxide"],
    ["<C-f>", "Files"],
    ["<C-g>", "Grep"],
  ];
  return `  ${items.map(([key, item]) => `${item === active ? ACCENT : SUB}${key} ${item}${RST}`).join(` ${DIM}·${RST} `)}`;
};

const canned = (now: number) =>
  [
    `${now - 60}|alpha:0|${work}/alpha||1`,
    `${now - 60}|alpha:1|${home}/zz||0`,
    `${now - 30}|aaa:0|${home}/mark||1`,
    `${now - 7200}|beta:0|${work}/Beta||1`,
    `${now - 200000}|gamma:2|${home}/zz||1`,
    `${now - 10 * 86400}|old:0|${root}/homex||1`,
    `|parkd:0|${home}/fav|1|1`,
  ].join("\n") + "\n";

beforeAll(() => {
  root = realpathSync(mkdtempSync(join(tmpdir(), "switcher-")));
  home = join(root, "home");
  work = join(home, "work");
  state = join(root, "state");
  stubs = join(root, "stubs");
  log = join(root, "tmux.log");
  windows = join(root, "windows");
  zoxide = join(root, "zoxide");
  marks = join(state, "switcher", "bookmarks");
  for (const dir of ["alpha", "Beta", "_under", "café", ".hidden", ".git"]) mkdirSync(join(work, dir), { recursive: true });
  for (const dir of ["fav", "off", "cfg", "mark", "zz", ".config/tmux", ".dotfiles"]) mkdirSync(join(home, dir), { recursive: true });
  mkdirSync(join(root, "homex"));
  mkdirSync(stubs);
  put(join(work, "alpha", "README.md"), "# Alpha\n");
  put(join(work, "notes.txt"), "one\nneedle here\nthree\n");
  put(join(work, "café", "needle.md"), "x needle\ty\n");
  put(join(work, ".hidden", "n.txt"), "needle\r\n");
  put(join(work, ".git", "needle"), "needle\n");
  put(join(work, "bin.dat"), new Uint8Array([0, 1, 2, 255, 0, 7, 0, 0, 200, 13]));
  stub(
    "tmux",
    `{ for a in "$@"; do printf '[%s]' "$a"; done; printf '\\n'; } >> "$SWT_LOG"
if [ "$1" = list-windows ] && [ -f "$SWT_WINDOWS" ]; then cat "$SWT_WINDOWS"; exit 0; fi
exec ${REAL_TMUX} -L "$SWT_SOCKET" "$@"`,
  );
  stub("zoxide", `[ -f "$SWT_ZOXIDE" ] && cat "$SWT_ZOXIDE"; exit 0`);
  stub("bat", `printf 'bat'; for a in "$@"; do printf ' [%s]' "$a"; done; printf '\\n'`);
  stub("eza", `[ -n "$SWT_EZA_FAIL" ] && exit 1; printf 'eza'; for a in "$@"; do printf ' [%s]' "$a"; done; printf '\\n'`);
  stub("visual", `{ printf 'visual'; for a in "$@"; do printf '[%s]' "$a"; done; printf '\\n'; } >> "$SWT_LOG"`);
  stub(
    "fzf",
    `printf '%s\\0' "$@" > "$SWT_DIR/fzf.args"
cat > "$SWT_DIR/fzf.stdin"
{ printf '%s\\n' "$SWITCHER_TAB_FILE"; cat "$SWITCHER_TAB_FILE"; } > "$SWT_DIR/fzf.tab"
while [ -e "$SWT_DIR/fzf.block" ]; do sleep 0.05; done
[ -f "$SWT_DIR/fzf.out" ] && cat "$SWT_DIR/fzf.out"
exit 0`,
  );
  tmux("-f", "/dev/null", "new-session", "-d", "-s", "alpha", "-c", work, "sleep", "86400");
  tmux("new-session", "-d", "-s", "beta", "-c", work, "sleep", "86400");
  tmux("new-window", "-d", "-t", "beta:1", "-c", work, "sleep", "86400");
});

afterAll(() => {
  tmux("kill-server");
  rmSync(root, { recursive: true, force: true });
});

afterEach(() => {
  for (const session of ["hidden", "alpha-2", "alpha-3", "_under", "Beta", "Beta-2", "shown"]) tmux("kill-session", "-t", `=${session}`);
  tmux("set", "-t", "=beta:", "-u", "@parked");
});

beforeEach(() => {
  put(log, "");
  put(marks, `${home}/mark\n${work}/alpha\n`);
  put(windows, canned(Math.floor(Date.now() / 1000)));
  put(
    zoxide,
    `  12.5 ${work}/alpha\n 300.0 ${home}/zz\n   5.0 ${root}/gone\n   1.0 ${root}/homex\n  70.0 ${home}/cfg\n`,
  );
  put(
    join(home, ".config", "switcher", "projects.json"),
    JSON.stringify({
      configDirs: ["~/cfg", "~/nope"],
      baseFolders: [{ scope: "Work", path: "~/work" }, { path: "~/absent" }],
      favorites: [{ rootPath: "~/fav/" }, { rootPath: "~/off", enabled: false }, { name: "no root" }],
    }),
  );
  for (const file of ["fzf.args", "fzf.stdin", "fzf.tab", "fzf.out", "fzf.block", "tab"]) rmSync(join(root, file), { force: true });
});

test("--source tmux lists active windows by recency tier, ties in reverse collation, parked last", () => {
  const r = run(["--source", "tmux"]);
  expect(r.code).toBe(0);
  expect(r.out).toBe(
    row("tmux", "alpha:0", `${work}/alpha`, true) +
      row("tmux", "aaa:0", `${home}/mark`, true) +
      row("tmux", "beta:0", `${work}/Beta`) +
      row("tmux", "gamma:2", `${home}/zz`) +
      row("tmux", "old:0", `${root}/homex`) +
      row("parked", "parkd:0", `${home}/fav`),
  );
});

test("--source tmux reads the live server: never-attached sessions share the lowest tier", () => {
  rmSync(windows);
  const r = run(["--source", "tmux"]);
  expect(keys(r.out)).toEqual([`tmux|beta:0|${work}`, `tmux|alpha:0|${work}`]);
});

test("--source all merges by path: the higher-priority source names the row, the best score orders it", () => {
  const r = run(["--source", "all"]);
  expect(r.code).toBe(0);
  expect(keys(r.out)).toEqual([
    `tmux|alpha:0|${work}/alpha`,
    `tmux|aaa:0|${home}/mark`,
    `tmux|beta:0|${work}/Beta`,
    `tmux|gamma:2|${home}/zz`,
    `tmux|old:0|${root}/homex`,
    `parked|parkd:0|${home}/fav`,
    `proj||${work}/café`,
    `proj||${work}/_under`,
    `conf||${home}/cfg`,
  ]);
  expect(r.out.split("\n")[6] + "\n").toBe(row("proj", "", `${work}/café`));
});

test("--source all ranks zoxide paths by score against the config-dir floor of 50", () => {
  put(windows, "");
  rmSync(join(home, ".config", "switcher", "projects.json"));
  put(marks, "");
  const r = run(["--source", "all"]);
  expect(keys(r.out)).toEqual([
    `zox||${home}/zz`,
    `zox||${home}/cfg`,
    `conf||${home}/.dotfiles`,
    `conf||${home}/.config/tmux`,
    `zox||${work}/alpha`,
    `zox||${root}/homex`,
  ]);
});

test("--source proj lists bookmarks, then favorites, then base-folder children in collation order, once each", () => {
  const r = run(["--source", "proj"]);
  expect(r.code).toBe(0);
  expect(r.out).toBe(
    row("proj", "", `${home}/mark`, true) +
      row("proj", "", `${work}/alpha`, true) +
      row("proj", "", `${home}/fav`) +
      row("proj", "", `${work}/_under`) +
      row("proj", "", `${work}/Beta`) +
      row("proj", "", `${work}/café`),
  );
});

test("--source proj sorts base-folder children in byte order under the C locale", () => {
  const r = run(["--source", "proj"], { LC_ALL: "C" });
  expect(keys(r.out).slice(3)).toEqual([`proj||${work}/Beta`, `proj||${work}/_under`, `proj||${work}/café`]);
});

test("--source conf expands ~ and skips missing config dirs", () => {
  const r = run(["--source", "conf"]);
  expect(r.code).toBe(0);
  expect(r.out).toBe(row("conf", "", `${home}/cfg`));
});

test("--source conf falls back to the default dirs without a usable projects.json", () => {
  const want = row("conf", "", `${home}/.config/tmux`) + row("conf", "", `${home}/.dotfiles`);
  rmSync(join(home, ".config", "switcher", "projects.json"));
  expect(run(["--source", "conf"]).out).toBe(want);
  put(join(home, ".config", "switcher", "projects.json"), "{ not json");
  expect(run(["--source", "conf"]).out).toBe(want);
});

test("--source zox keeps zoxide order, drops missing dirs, and shortens a bare $HOME prefix", () => {
  const r = run(["--source", "zox"], { HOME: `${home}/wo` });
  expect(r.out).toBe(
    row("zox", "", `${work}/alpha`, true, `${home}/wo`) +
      row("zox", "", `${home}/zz`, false, `${home}/wo`) +
      row("zox", "", `${root}/homex`, false, `${home}/wo`) +
      row("zox", "", `${home}/cfg`, false, `${home}/wo`),
  );
  expect(r.out).toContain(`${DIM}~rk/alpha${RST}`);
});

test("--source search files lists files and dirs under the pane path with base64 targets", () => {
  const r = run(["--source", "search", "files"]);
  expect(r.code).toBe(0);
  const want = [
    fileRow(`${work}/alpha`, true),
    fileRow(`${work}/alpha/README.md`),
    fileRow(`${work}/Beta`),
    fileRow(`${work}/_under`),
    fileRow(`${work}/café`),
    fileRow(`${work}/café/needle.md`),
    fileRow(`${work}/.hidden`),
    fileRow(`${work}/.hidden/n.txt`),
    fileRow(`${work}/notes.txt`),
    fileRow(`${work}/bin.dat`),
  ];
  expect(r.out.split(/(?<=\n)/).sort()).toEqual(want.sort());
});

test("--source search files shortens $HOME only at a path boundary", () => {
  const r = run(["--source", "search", "files"], { HOME: `${home}/wo` });
  expect(r.out).toContain(fileRow(`${work}/notes.txt`, false, `${home}/wo`));
  expect(r.out).not.toContain("~rk");
});

test("--source search files falls back to $HOME when tmux has no server", () => {
  const r = run(["--source", "search", "files"], { SWT_SOCKET: `${SOCKET}-none`, HOME: work });
  expect(r.out).toContain(fileRow(`${work}/notes.txt`, false, work));
});

test("--source search text greps the pane path and flattens control characters", () => {
  const r = run(["--source", "search", "text", "needle"]);
  expect(r.code).toBe(0);
  const want = [
    textRow(`${work}/notes.txt`, 2, "needle here "),
    textRow(`${work}/café/needle.md`, 1, "x needle y "),
    textRow(`${work}/.hidden/n.txt`, 1, "needle  "),
  ];
  expect(r.out.split(/(?<=\n)/).sort()).toEqual(want.sort());
});

test("--source search text with an empty query prints nothing", () => {
  const r = run(["--source", "search", "text"]);
  expect(r.code).toBe(0);
  expect(r.out).toBe("");
});

test("--source names its tab in SWITCHER_TAB_FILE, without the grep query", () => {
  const tab = join(root, "tab");
  run(["--source", "proj"], { SWITCHER_TAB_FILE: tab });
  expect(readFileSync(tab, "utf8")).toBe("proj \n");
  run(["--source", "search", "text", "needle"], { SWITCHER_TAB_FILE: tab });
  expect(readFileSync(tab, "utf8")).toBe("search text\n");
});

test("--source with an unknown tab exits 1 after it records the tab", () => {
  const tab = join(root, "tab");
  const r = run(["--source", "bogus"], { SWITCHER_TAB_FILE: tab });
  expect(r.code).toBe(1);
  expect(r.err).toBe("Unknown source: bogus\n");
  expect(r.out).toBe("");
  expect(readFileSync(tab, "utf8")).toBe("bogus \n");
});

test("--source-current replays the recorded tab, and grep comes back empty", () => {
  const tab = join(root, "tab");
  const zox = run(["--source", "zox"]).out;
  expect(zox).toContain(`zox||${home}/zz`);
  put(tab, "zox \n");
  expect(run(["--source-current"], { SWITCHER_TAB_FILE: tab }).out).toBe(zox);
  put(tab, "search text\n");
  const grep = run(["--source-current"], { SWITCHER_TAB_FILE: tab });
  expect(grep.code).toBe(0);
  expect(grep.out).toBe("");
  expect(readFileSync(tab, "utf8")).toBe("search text\n");
});

test("--source-current replays a file-search tab", () => {
  const tab = join(root, "tab");
  put(tab, "search files\n");
  const replay = run(["--source-current"], { SWITCHER_TAB_FILE: tab });
  expect(replay.code).toBe(0);
  expect(replay.out).toContain(fileRow(`${work}/notes.txt`));
  expect(replay.out.split(/(?<=\n)/).sort()).toEqual(run(["--source", "search", "files"]).out.split(/(?<=\n)/).sort());
});

test("a file search whose reader closes early exits 141 without an error", () => {
  const big = join(root, "big");
  for (let i = 0; i < 3000; i++) mkdirSync(join(big, `dir-${i}`), { recursive: true });
  const proc = Bun.spawnSync(
    ["bash", "-c", '"$@" | head -c 100 > /dev/null; echo "${PIPESTATUS[0]}"', "_", ...RUNNER, SCRIPT, "--source", "search", "files"],
    { cwd: root, env: env({ SWT_SOCKET: `${SOCKET}-none`, HOME: big }) },
  );
  expect(proc.stdout.toString()).toBe("141\n");
  expect(proc.stderr.toString()).toBe("");
  rmSync(big, { recursive: true, force: true });
});

test("a SIGHUP while fzf is open removes the tab file", async () => {
  const block = join(root, "fzf.block");
  put(block);
  const proc = Bun.spawn([...RUNNER, SCRIPT], { cwd: root, env: env(), stderr: "ignore" });
  try {
    const seen = () => (existsSync(join(root, "fzf.tab")) ? readFileSync(join(root, "fzf.tab"), "utf8") : "");
    for (let i = 0; i < 100 && !seen().includes("all "); i++) await Bun.sleep(50);
    const [tab] = seen().split("\n");
    expect(existsSync(tab)).toBe(true);
    proc.kill("SIGHUP");
    await proc.exited;
    expect(proc.exitCode === 129 || proc.signalCode === "SIGHUP").toBe(true);
    expect(existsSync(tab)).toBe(false);
  } finally {
    proc.kill("SIGKILL");
    rmSync(block, { force: true });
  }
});

test("--source-current without a tab file lists all", () => {
  const r = run(["--source-current"]);
  expect(r.code).toBe(0);
  expect(r.out).toBe(run(["--source", "all"]).out);
});

test("--bookmark adds then removes a dir and asks fzf to reload the current tab", () => {
  const entry = row("zox", "", `${home}/zz/`).trimEnd();
  const added = run(["--bookmark", entry]);
  expect(added.code).toBe(0);
  expect(added.out).toBe(`reload(${SCRIPT} --source-current)`);
  expect(readFileSync(marks, "utf8")).toBe(`${home}/mark\n${work}/alpha\n${home}/zz\n`);
  const removed = run(["--bookmark", entry]);
  expect(removed.out).toBe(`reload(${SCRIPT} --source-current)`);
  expect(readFileSync(marks, "utf8")).toBe(`${home}/mark\n${work}/alpha\n`);
});

test("--bookmark decodes a file-search row and creates the state dir", () => {
  rmSync(join(state, "switcher"), { recursive: true });
  const r = run(["--bookmark", fileRow(`${work}/café`).trimEnd()]);
  expect(r.out).toBe(`reload(${SCRIPT} --source-current)`);
  expect(readFileSync(marks, "utf8")).toBe(`${work}/café\n`);
});

test("--bookmark ignores a path that is not a dir and still exits 0", () => {
  const r = run(["--bookmark", fileRow(`${work}/notes.txt`).trimEnd()]);
  expect(r.code).toBe(0);
  expect(r.out).toBe("");
  expect(readFileSync(marks, "utf8")).toBe(`${home}/mark\n${work}/alpha\n`);
});

test("--preview of a session prints its active pane", async () => {
  tmux("new-session", "-d", "-s", "shown", "-c", work, "sh", "-c", "printf 'hello-preview\\n'; exec cat");
  for (let i = 0; i < 50 && !tmux("capture-pane", "-t", "shown:", "-p").includes("hello-preview"); i++) await Bun.sleep(100);
  const r = run(["--preview", row("tmux", "shown:0", work).trimEnd()]);
  expect(r.out).toStartWith("hello-preview\n");
});

test("--preview of a gone session prints the fallback", () => {
  const r = run(["--preview", row("tmux", "ghost:0", work).trimEnd()]);
  expect(r.out).toBe("No preview available\n");
});

test("--preview of a project shows its README with bat", () => {
  const r = run(["--preview", row("proj", "", `${work}/alpha`).trimEnd()]);
  expect(r.out).toBe(`bat [-n] [--color=always] [--style=plain] [${work}/alpha/README.md]\n`);
});

test("--preview of a project without a README shows an eza tree, or ls -la when eza fails", () => {
  const entry = row("conf", "", `${work}/café`).trimEnd();
  expect(run(["--preview", entry]).out).toBe(
    `eza [--tree] [--level=2] [--icons] [--color=always] [--group-directories-first] [--ignore-glob=${IGNORE}] [${work}/café]\n`,
  );
  const r = run(["--preview", entry], { SWT_EZA_FAIL: "1" });
  expect(r.out).toContain("needle.md");
  expect(r.out).toContain("..");
});

test("--preview of a grep hit highlights the line in a window around it", () => {
  const hit = (line: number) => textRow(`${work}/notes.txt`, line, "x").trimEnd();
  const args = (range: string, line: number) =>
    `bat [--color=always] [--style=numbers] [--highlight-line] [${line}] [--line-range] [${range}] [--] [${work}/notes.txt]\n`;
  expect(run(["--preview", hit(2)]).out).toBe(args("1:52", 2));
  expect(run(["--preview", hit(25)]).out).toBe(args("5:75", 25));
});

test("--preview of a file-search row shows text with bat, binary with file, and dirs with eza", () => {
  expect(run(["--preview", fileRow(`${work}/notes.txt`).trimEnd()]).out).toBe(
    `bat [--color=always] [--style=numbers] [--line-range=:500] [--] [${work}/notes.txt]\n`,
  );
  const kind = Bun.spawnSync(["file", "--brief", "--", `${work}/bin.dat`]).stdout.toString();
  expect(run(["--preview", fileRow(`${work}/bin.dat`).trimEnd()]).out).toBe(kind);
  expect(run(["--preview", fileRow(`${work}/Beta`).trimEnd()]).out).toStartWith("eza [--tree]");
});

const pick = (key: string, entry: string, extra: Record<string, string> = {}) => {
  put(join(root, "fzf.out"), `${key}\n${entry}\n`);
  return run([], extra);
};

test("bare run hands the all list to fzf with the switcher options and removes its tab file", () => {
  const all = run(["--source", "all"]).out;
  put(log, "");
  const r = run([]);
  expect(r.code).toBe(0);
  expect(actions()).toEqual([]);
  expect(readFileSync(join(root, "fzf.stdin"), "utf8")).toBe(all);
  const [tab, content] = readFileSync(join(root, "fzf.tab"), "utf8").split("\n");
  expect(tab).toStartWith("/tmp/switcher-tab.");
  expect(content).toBe("all ");
  expect(existsSync(tab)).toBe(false);
  const self = (text: string) => text.replaceAll(SCRIPT, "SELF");
  const navFooter = `${DIM}  Connect <CR> ◆ Bookmark <C-s> ◆ Editor <C-e> ◆ Zed <C-v> ◆ Kill <C-d> ◆ Preview <C-/>${RST}`;
  const tmuxFooter = `${DIM}  Switch <CR> ◆ Bookmark <C-s> ◆ Kill <C-d> ◆ Preview <C-/>${RST}`;
  const filesFooter = `${DIM}  Open <CR> ◆ Editor <C-e> ◆ Zed <C-v> ◆ Preview <C-/> ◆ Text grep <C-g>${RST}`;
  const grepFooter = `${DIM}  Open <CR> ◆ Editor <C-e> ◆ Zed <C-v> ◆ Files <C-f> ◆ Regex query${RST}`;
  const show = (icon: string, label: string, hdr: string, footer: string) =>
    `change-prompt(${icon}  ${label} ❯ )+change-header(${header(hdr)})+change-footer(${footer})`;
  const tabBind = (source: string, icon: string, label: string, hdr: string, footer: string) =>
    `unbind(change)+enable-search+reload(SELF --source ${source})+${show(icon, label, hdr, footer)}`;
  expect(self(readFileSync(join(root, "fzf.args"), "utf8")).split("\0").slice(0, -1)).toEqual([
    "--tmux",
    "center,55%,60%",
    "--ansi",
    "--no-info",
    "--cycle",
    "--tiebreak=begin,index",
    "--no-keep-right",
    "--delimiter",
    "\t",
    "--with-nth",
    "2..",
    "--nth",
    "1,3..",
    "--border",
    "rounded",
    "--border-label",
    " Switcher ",
    "--padding=1,2",
    "--color",
    COLORS,
    "--header",
    header("All"),
    "--header-first",
    "--header-border=line",
    "--prompt",
    `${ICON.project}  All ❯ `,
    "--footer",
    navFooter,
    "--footer-border=line",
    "--preview",
    "SELF --preview {}",
    "--preview-window",
    "bottom:30%:wrap:hidden",
    "--bind",
    "start:unbind(change)",
    "--bind",
    "change:reload(SELF --source search text {q})",
    "--bind",
    `ctrl-a:${tabBind("all", ICON.project, "All", "All", navFooter)}`,
    "--bind",
    `ctrl-t:${tabBind("tmux", ICON.session, "Sessions", "Sessions", tmuxFooter)}`,
    "--bind",
    `ctrl-p:${tabBind("proj", ICON.project, "Projects", "Projects", navFooter)}`,
    "--bind",
    `ctrl-z:${tabBind("zox", ICON.zoxide, "Zoxide", "Zoxide", navFooter)}`,
    "--bind",
    `ctrl-f:${tabBind("search files", ICON.files, "Files", "Files", filesFooter)}`,
    "--bind",
    `ctrl-g:disable-search+rebind(change)+reload(SELF --source search text {q})+${show(ICON.text, "Grep", "Grep", grepFooter)}+hide-preview`,
    "--bind",
    "ctrl-s:transform(SELF --bookmark {})",
    "--bind",
    "ctrl-/:toggle-preview",
    "--bind",
    "ctrl-o:toggle-preview",
    "--expect",
    "ctrl-e,ctrl-v,ctrl-d",
    "--bind",
    "esc:abort",
  ]);
});

test("Enter on a session row switches to it and selects the window", () => {
  const r = pick("", row("tmux", "beta:1", work).trimEnd());
  expect(actions()).toEqual(["[switch-client][-t][=beta]", "[select-window][-t][beta:1]"]);
  expect(r.code).toBe(0);
});

test("Enter on a parked row unparks it before the switch", () => {
  tmux("set", "-t", "=beta:", "@parked", "1");
  pick("", row("parked", "beta:1", work).trimEnd());
  expect(actions()).toEqual([
    "[set][-t][=beta:][-u][@parked]",
    "[switch-client][-t][=beta]",
    "[select-window][-t][beta:1]",
  ]);
  expect(tmux("show", "-t", "=beta:", "-v", "@parked")).toBe("");
});

test("ctrl-d on a session row asks tmux to confirm a kill by session id", () => {
  const id = tmux("display-message", "-p", "-t", "beta:", "#{session_id}");
  const r = pick("ctrl-d", row("tmux", "beta:0", work).trimEnd());
  expect(actions()).toEqual([
    "[list-sessions][-F][#{session_id} #{session_name}]",
    `[confirm-before][-p][Kill beta? (y/n)][kill-session -t ${id}]`,
  ]);
  expect(r.code).toBe(1);
  expect(tmux("list-sessions", "-F", "#{session_name}").split("\n")).toContain("beta");
});

test("ctrl-d on a gone session reports it with # escaped", () => {
  const r = pick("ctrl-d", row("tmux", "gh#ost:0", work).trimEnd());
  expect(actions()).toEqual(["[list-sessions][-F][#{session_id} #{session_name}]", "[display-message][No session gh##ost]"]);
  expect(r.code).toBe(0);
});

test("Enter on a project creates a session named after the dir, without a leading dot", () => {
  const r = pick("", row("proj", "", `${work}/.hidden`).trimEnd());
  expect(actions()).toEqual([
    "[has-session][-t][=hidden]",
    `[new-session][-d][-s][hidden][-c][${work}/.hidden]`,
    "[switch-client][-t][=hidden]",
  ]);
  expect(r.code).toBe(1);
  expect(tmux("display-message", "-p", "-t", "hidden:", "#{session_path}")).toBe(`${work}/.hidden`);
});

test("Enter on a project whose name is taken adds the first free suffix", () => {
  tmux("new-session", "-d", "-s", "alpha-2", "-c", work, "sleep", "86400");
  pick("", row("zox", "", `${work}/alpha`).trimEnd());
  expect(actions()).toEqual([
    "[has-session][-t][=alpha]",
    "[display-message][-t][=alpha:][-p][#{session_path}]",
    "[has-session][-t][=alpha-2]",
    "[has-session][-t][=alpha-3]",
    `[new-session][-d][-s][alpha-3][-c][${work}/alpha]`,
    "[switch-client][-t][=alpha-3]",
  ]);
});

test("Enter on a project whose session already points at it reuses that session", () => {
  tmux("new-session", "-d", "-s", "Beta", "-c", `${work}/Beta`, "sleep", "86400");
  pick("", row("proj", "", `${work}/Beta`).trimEnd());
  expect(actions()).toEqual([
    "[has-session][-t][=Beta]",
    "[display-message][-t][=Beta:][-p][#{session_path}]",
    `[new-session][-d][-s][Beta][-c][${work}/Beta]`,
    "[switch-client][-t][=Beta]",
  ]);
  expect(tmux("list-sessions", "-F", "#{session_name}").split("\n")).not.toContain("Beta-2");
});

test("ctrl-e opens $EDITOR in a new window and ctrl-v hands the path to $VISUAL", () => {
  expect(pick("ctrl-e", row("proj", "", `${work}/Beta`).trimEnd()).code).toBe(0);
  expect(actions()).toEqual([`[new-window][-c][${work}/Beta][/usr/bin/true]`]);
  put(log, "");
  expect(pick("ctrl-v", row("conf", "", `${work}/Beta`).trimEnd()).code).toBe(0);
  expect(actions()).toEqual([`visual[${work}/Beta]`]);
});

test("a $VISUAL that is not a command exits 127", () => {
  expect(pick("ctrl-v", row("proj", "", `${work}/Beta`).trimEnd(), { VISUAL: "no-such-visual-cmd" }).code).toBe(127);
});

test("ctrl-v runs a waiting $VISUAL without its wait flag", () => {
  const waiting = { VISUAL: `${join(stubs, "visual")} --wait` };
  expect(pick("ctrl-v", row("proj", "", `${work}/Beta`).trimEnd(), waiting).code).toBe(0);
  expect(actions()).toEqual([`visual[${work}/Beta]`]);
});

test("a grep hit opens at its line, in the editor or in $VISUAL", () => {
  const hit = textRow(`${work}/notes.txt`, 2, "needle here ").trimEnd();
  pick("", hit);
  expect(actions()).toEqual([`[new-window][-c][${work}][/usr/bin/true][+2][${work}/notes.txt]`]);
  put(log, "");
  pick("ctrl-v", hit);
  expect(actions()).toEqual([`visual[${work}/notes.txt:2]`]);
});

test("a file-search file opens in the editor, and a file-search dir connects a session", () => {
  pick("ctrl-e", fileRow(`${work}/café/needle.md`).trimEnd());
  expect(actions()).toEqual([`[new-window][-c][${work}/café][/usr/bin/true][${work}/café/needle.md]`]);
  put(log, "");
  pick("", fileRow(`${work}/_under`).trimEnd());
  expect(actions()).toEqual([
    "[has-session][-t][=_under]",
    `[new-session][-d][-s][_under][-c][${work}/_under]`,
    "[switch-client][-t][=_under]",
  ]);
});
