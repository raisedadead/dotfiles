import { afterEach, beforeEach, expect, setDefaultTimeout, test } from "bun:test";
import {
  chmodSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  realpathSync,
  rmSync,
  symlinkSync,
  utimesSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";

const SCRIPT = resolve(import.meta.dir, "../../exact_dot_bin/executable_chezmoi-claude-doctor");
const DAY = 86_400_000;

setDefaultTimeout(120_000);

const SETTINGS = { switchModelsOnFlag: false, mcpServers: { srv: { type: "http", url: "u" } } };
const RUNTIME = { mcpServers: { srv: { type: "http", url: "u" } } };

let base: string;
let home: string;
let ctl: string;
let bin: string;
let tools: string;
let claude: string;
let src: string;
let sub: string;

const doctor = [process.execPath, "--no-env-file", "--config=/dev/null", SCRIPT];

const put = (path: string, text = "", mode?: number) => {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, text);
  if (mode !== undefined) chmodSync(path, mode);
};

const json = (path: string, value: unknown, mode?: number) => put(path, JSON.stringify(value), mode);

const link = (target: string, path: string) => {
  mkdirSync(dirname(path), { recursive: true });
  symlinkSync(target, path);
};

const age = (path: string, days: number) => {
  const at = new Date(Date.now() - days * DAY);
  utimesSync(path, at, at);
};

const stub = (name: string, body: string) => put(join(bin, name), `#!/usr/bin/env bash\n${body}\n`, 0o755);

const baseEnv = (): Record<string, string> => ({
  HOME: home,
  PATH: `${bin}:${tools}:/usr/bin:/bin:/usr/sbin:/sbin`,
  DOCTOR_CTL: ctl,
  GIT_CONFIG_NOSYSTEM: "1",
  GIT_CONFIG_GLOBAL: "/dev/null",
});

const git = (cwd: string, ...args: string[]) => {
  const proc = Bun.spawnSync(
    ["git", "-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false", "-c", "protocol.file.allow=always", ...args],
    { cwd, env: baseEnv() },
  );
  if (proc.exitCode !== 0) throw new Error(`git ${args.join(" ")}: ${proc.stderr}`);
  return proc.stdout.toString().trim();
};

type Opts = { cwd?: string; env?: Record<string, string | undefined>; stdin?: string };

const run = (args: string[] = [], opts: Opts = {}) => {
  const env: Record<string, string> = baseEnv();
  for (const [key, value] of Object.entries(opts.env ?? {})) {
    if (value === undefined) delete env[key];
    else env[key] = value;
  }
  const proc = Bun.spawnSync([...doctor, ...args], {
    cwd: opts.cwd ?? base,
    env,
    stdin: opts.stdin === undefined ? "ignore" : Buffer.from(opts.stdin),
  });
  return { code: proc.exitCode, out: proc.stdout.toString(), err: proc.stderr.toString() };
};

const section = (out: string, head: string) => {
  const at = out.indexOf(head);
  if (at < 0) return "";
  const end = out.indexOf("\n\n", at);
  return out.slice(at, end < 0 ? undefined : end);
};

const marker = () => join(claude, "markers", "doctor-warnings.txt");
const managed = (...paths: string[]) => put(join(ctl, "managed"), `${paths.join("\n")}\n`);

beforeEach(() => {
  base = realpathSync(mkdtempSync(join(tmpdir(), "doctor-")));
  home = join(base, "home");
  ctl = join(base, "ctl");
  bin = join(base, "bin");
  tools = join(base, "tools");
  claude = join(home, ".claude");
  src = join(home, ".dotfiles");
  sub = join(src, "dot_claude");
  mkdirSync(ctl, { recursive: true });
  mkdirSync(tools, { recursive: true });
  mkdirSync(join(base, "outside"), { recursive: true });
  for (const tool of ["git", "bash"]) {
    const path = Bun.which(tool);
    if (!path) throw new Error(`missing ${tool}`);
    symlinkSync(path, join(tools, tool));
  }
  stub(
    "chezmoi",
    `printf '%s\\n' "$*" >> "$DOCTOR_CTL/chezmoi-calls"
case "$1" in
managed) cat "$DOCTOR_CTL/managed" 2>/dev/null ;;
status) cat "$DOCTOR_CTL/status" 2>/dev/null; exit "$(cat "$DOCTOR_CTL/status-rc" 2>/dev/null || echo 0)" ;;
esac`,
  );

  const origin = join(base, "sub-origin");
  put(join(origin, "mods", "rig", "build.ts"), "x\n");
  git(base, "init", "-q", origin);
  git(origin, "add", ".");
  git(origin, "commit", "-q", "-m", "sub");
  git(base, "init", "-q", src);
  git(src, "submodule", "add", "-q", origin, "dot_claude");
  git(src, "commit", "-q", "-m", "super");
  json(join(sub, ".settings.managed.json"), SETTINGS);

  json(join(claude, "settings.json"), SETTINGS);
  put(join(claude, "agents", "a.md"), "a\n");
  json(join(home, ".claude.json"), RUNTIME, 0o600);
  managed(join(claude, "settings.json"), join(claude, "agents", "a.md"));
});

afterEach(() => rmSync(base, { recursive: true, force: true }));

const CLEAN = `[1/5] chezmoi status (managed-file modifications)
  clean

[2/5] coverage (unmanaged files inside managed dirs)
  clean

[3/5] shape (unmanaged top-level *.{md|toml|yaml|yml|kdl|ini})
  clean

[4/5] mcp drift (settings.json vs ~/.claude.json user-level)
  clean

[5/5] lint (enabledPlugins/mcpServers shape, CC version, skill name, skill layers)
  clean

Total issues: 0
[warn 1/6] first-party plugin drift (installed sha vs claude-code-plugins origin/main)
  skip (installed_plugins.json missing)

[warn 2/6] safeguard toggle (switchModelsOnFlag=false in source + live settings.json)
  clean

[warn 3/6] rig version gate (validate, type check and tests after a Claude Code update)
  skip (no host types; Claude Code writes them when it loads the rig)

[warn 4/6] AI release stores (Codex daemon and Pi keep at most two releases)
  skip (~/.codex/packages/app-server-daemon/releases missing)
  skip (~/.pi/agent/install/releases missing)
  clean

[warn 5/6] dangling links (~/.bin and ~/.claude/skills)
  clean

[warn 6/6] agent additions (Claude, Pi and Codex items outside the source and docs/agent-additions.txt)
  clean

`;

test("a clean machine prints every check and exits 0", () => {
  const r = run();
  expect(r.err).toBe("");
  expect(r.out).toBe(CLEAN);
  expect(r.code).toBe(0);
});

test("the sources default to ~/.dotfiles under HOME", () => {
  run();
  const calls = readFileSync(join(ctl, "chezmoi-calls"), "utf8");
  expect(calls).toContain(`managed --source ${src} --path-style absolute`);
  expect(calls).toContain(`status --source ${src} --path-style absolute -- ${claude}`);
});

test("--quiet prints nothing and keeps the exit code", () => {
  expect(run(["--quiet"])).toEqual({ code: 0, out: "", err: "" });
  put(join(claude, "notes.md"));
  expect(run(["--quiet"])).toEqual({ code: 1, out: "", err: "" });
});

test("an unknown flag exits 2", () => {
  const r = run(["--bogus"]);
  expect(r.code).toBe(2);
  expect(r.err).toBe("unknown arg: --bogus\n");
  expect(r.out).toBe("");
});

test("--help prints the usage and exits 0", () => {
  const r = run(["--help"]);
  expect(r.code).toBe(0);
  expect(r.out).toContain("Usage:");
  for (const flag of ["--quiet", "--rewake"]) expect(r.out).toContain(flag);
  expect(r.out).not.toContain("--test");
});

test("without chezmoi the doctor exits 2", () => {
  rmSync(join(bin, "chezmoi"));
  const r = run();
  expect(r.code).toBe(2);
  expect(r.err).toBe("missing dependency: chezmoi\n");
});

test("an uninitialised dot_claude submodule exits 2", () => {
  git(src, "submodule", "deinit", "-q", "-f", "dot_claude");
  const r = run();
  expect(r.code).toBe(2);
  expect(r.err).toBe(`dot_claude submodule not initialised: git -C ${src} submodule update --init\n`);
  expect(r.out).toBe("");
});

test("a missing managed settings file exits 2", () => {
  rmSync(join(sub, ".settings.managed.json"));
  const r = run();
  expect(r.code).toBe(2);
  expect(r.err).toBe(`missing ${sub}/.settings.managed.json\n`);
});

test("a submodule checkout ahead of the gitlink warns", () => {
  git(sub, "commit", "-q", "--allow-empty", "-m", "ahead");
  const r = run();
  expect(r.out.split("\n")[0]).toBe(`WARN: dot_claude checkout differs from the recorded gitlink; commit the bump in ${src}`);
  expect(r.code).toBe(0);
});

test("chezmoi status lines count as issues", () => {
  put(join(ctl, "status"), ` M ${claude}/b\n A ${claude}/a\n`);
  const r = run();
  expect(section(r.out, "[1/5]")).toBe(`[1/5] chezmoi status (managed-file modifications)\n A ${claude}/a\n M ${claude}/b`);
  expect(r.out).toContain("Total issues: 2\n");
  expect(r.code).toBe(1);
});

test("a failed chezmoi status counts as one issue", () => {
  put(join(ctl, "status"), "partial\n");
  put(join(ctl, "status-rc"), "1\n");
  const r = run();
  expect(section(r.out, "[1/5]")).toBe("[1/5] chezmoi status (managed-file modifications)\n  ERROR: chezmoi status failed");
  expect(r.out).toContain("Total issues: 1\n");
  expect(r.code).toBe(1);
});

test("coverage reports unmanaged files in managed dirs and obeys .chezmoiignore", () => {
  put(
    join(src, ".chezmoiignore"),
    [
      "# comment",
      ".claude/agents/skip.md   # exact",
      ".claude/agents/ign",
      ".claude/agents/deep/**",
      ".claude/agents/**/*.tmp",
      ".claude/agents/g*.md",
      "!.claude/agents/neg.md",
      "other/orphan.md",
      "",
    ].join("\n"),
  );
  for (const name of ["skip.md", "ign/x.md", "deep/y/z.md", "sub/w.tmp", "g1.md", "orphan.md", "neg.md"]) {
    put(join(claude, "agents", name));
  }
  const r = run();
  const lines = section(r.out, "[2/5]").split("\n").slice(1).sort();
  expect(lines).toEqual([`  ORPHAN: ${claude}/agents/neg.md`, `  ORPHAN: ${claude}/agents/orphan.md`]);
  expect(r.out).toContain("Total issues: 2\n");
  expect(r.code).toBe(1);
});

test("shape reports unmanaged top-level config files", () => {
  put(join(claude, "notes.md"));
  put(join(claude, "CLAUDE.md"));
  put(join(claude, "x.json"));
  put(join(claude, "deep", "inner.md"));
  managed(join(claude, "settings.json"), join(claude, "agents", "a.md"), join(claude, "CLAUDE.md"));
  const r = run();
  expect(section(r.out, "[3/5]")).toBe(`[3/5] shape (unmanaged top-level *.{md|toml|yaml|yml|kdl|ini})\n  ORPHAN: ${claude}/notes.md`);
  const json = run([], { env: { SHAPE_EXTS: "json" } });
  expect(section(json.out, "[3/5]")).toBe(`[3/5] shape (unmanaged top-level *.{json})\n  ORPHAN: ${claude}/x.json`);
});

test("mcp drift prints a diff from the live file to the source", () => {
  json(join(home, ".claude.json"), { mcpServers: { srv: { url: "v", type: "http" } }, other: 1 }, 0o600);
  const r = run();
  expect(section(r.out, "[4/5]")).toBe(
    [
      "[4/5] mcp drift (settings.json vs ~/.claude.json user-level)",
      "  DRIFT in mcpServers (dot_claude/.settings.managed.json is canonical)",
      "  --- .claude.json",
      "  +++ settings.json",
      "  @@ -1,6 +1,6 @@",
      "   {",
      '     "srv": {',
      '       "type": "http",',
      '  -    "url": "v"',
      '  +    "url": "u"',
      "     }",
      "   }",
    ].join("\n"),
  );
  expect(r.code).toBe(1);
});

test("mcp drift checks the mode and the readability of ~/.claude.json", () => {
  chmodSync(join(home, ".claude.json"), 0o644);
  expect(section(run().out, "[4/5]")).toEndWith("\n  DRIFT: ~/.claude.json mode is 644, not 600");
  put(join(home, ".claude.json"), "{not json", 0o600);
  expect(section(run().out, "[4/5]")).toEndWith("\n  LINT: ~/.claude.json is not valid JSON");
  rmSync(join(home, ".claude.json"));
  const r = run();
  expect(section(r.out, "[4/5]")).toEndWith("\n  DRIFT: ~/.claude.json is absent or unreadable");
  expect(r.code).toBe(1);
});

test("mcp drift skips a source without mcpServers", () => {
  json(join(sub, ".settings.managed.json"), { switchModelsOnFlag: false });
  json(join(claude, "settings.json"), { switchModelsOnFlag: false });
  const r = run();
  expect(section(r.out, "[4/5]")).toEndWith("\n  skip (settings.json declares no mcpServers; apply is a passthrough)");
  expect(r.code).toBe(0);
});

test("lint flags settings shape, skill names and skill layers", () => {
  const settings = {
    ...SETTINGS,
    enabledPlugins: { "ok@m": true, "arr@m": ["x"] },
    mcpServers: { ...SETTINGS.mcpServers, notype: { command: "x" } },
  };
  json(join(sub, ".settings.managed.json"), settings);
  json(join(claude, "settings.json"), settings);
  json(join(home, ".claude.json"), { mcpServers: settings.mcpServers }, 0o600);
  stub("claude", 'echo "9.9.2 (Claude Code)"');
  put(join(sub, "skills", "foo", "SKILL.md"), "---\nname: \"bar\"\n---\n");
  put(join(sub, "skills", "same", "SKILL.md"), "---\nname: 'same'\n---\n");
  put(join(src, "dot_agents", "skills", "lone", "SKILL.md"), "---\nname: other\n---\n");
  link("../../.agents/skills/dang", join(claude, "skills", "dang"));
  link("/tmp", join(claude, "skills", "odd"));
  put(join(sub, "skills", "symlink_x"), "../../.agents/skills/x\n");
  put(join(sub, "skills", "symlink_lone"), "../../.agents/skills/wrong\n");
  put(join(src, "dot_agents", "skills", "common", "SKILL.md"), "---\nname: common\n---\n");
  json(join(base, "state", "skills", ".skill-lock.json"), { skills: { common: {} } });
  const r = run([], { env: { XDG_STATE_HOME: join(base, "state") } });
  const lines = section(r.out, "[5/5]").split("\n").slice(1);
  const lock = join(base, "state", "skills", ".skill-lock.json");
  expect(lines.slice(0, 4)).toEqual([
    "  LINT: enabledPlugins[arr@m] is not boolean (CC 2.1.x silently disables array form)",
    "  LINT: mcpServers[notype] missing 'type' field (stdio/http/sse)",
    "  INFO: claude --version=9.9.2 (informational)",
    `  LINT: skill frontmatter name='bar' != dir='foo' (${sub}/skills/foo/SKILL.md)`,
  ]);
  expect(lines).toContain(`  LINT: skill frontmatter name='other' != dir='lone' (${src}/dot_agents/skills/lone/SKILL.md)`);
  expect(lines).toContain(`  LINT: skill link ${claude}/skills/dang is dangling`);
  expect(lines).toContain(`  LINT: skill link ${claude}/skills/odd targets '/tmp', not '../../.agents/skills/odd'`);
  expect(lines).toContain(`  LINT: ${sub}/skills/symlink_x has no ${src}/dot_agents/skills/x/SKILL.md`);
  expect(lines).toContain(`  LINT: ${sub}/skills/symlink_lone holds '../../.agents/skills/wrong', not '../../.agents/skills/lone'`);
  expect(lines).toContain(`  LINT: common skill 'common' is also a CLI-installed copy (${lock})`);
  expect(lines).not.toContain("  clean");
  expect(lines.length).toBe(10);
  expect(r.out).toContain("Total issues: 9\n");
  expect(r.code).toBe(1);
});

test("plugin drift warns only when origin/main changes the plugin after the install", () => {
  const own = join(base, "own");
  const env = { OWN_PLUGIN_SRC: own };
  git(base, "init", "-q", own);
  git(own, "commit", "-q", "--allow-empty", "-m", "one");
  const c1 = git(own, "rev-parse", "HEAD");
  put(join(own, "plugins", "whetstone", "SKILL.md"), "two\n");
  git(own, "add", ".");
  git(own, "commit", "-q", "-m", "two");
  const c2 = git(own, "rev-parse", "HEAD");
  put(join(own, "plugins", "whetstone", "CHANGELOG.md"), "three\n");
  put(join(own, "tools", "test.sh"), "three\n");
  git(own, "add", ".");
  git(own, "commit", "-q", "-m", "three");
  const c3 = git(own, "rev-parse", "HEAD");
  const installed = (sha: string) =>
    json(join(claude, "plugins", "installed_plugins.json"), { plugins: { "whetstone@raisedadead-plugins": [{ gitCommitSha: sha }], "x@other": [{}] } });
  const drift = () => section(run([], { env }).out, "[warn 1/6]").split("\n").slice(1);

  git(own, "update-ref", "refs/remotes/origin/main", c1);
  installed(c1);
  expect(drift()).toEqual(["  clean"]);
  git(own, "update-ref", "refs/remotes/origin/main", c2);
  expect(drift()).toEqual([
    `  WARN: whetstone@raisedadead-plugins installed ${c1.slice(0, 12)} differs from plugins/whetstone on origin/main (${c2.slice(0, 12)}) — run /cmd-refresh-plugins`,
  ]);
  installed(c2);
  git(own, "update-ref", "refs/remotes/origin/main", c3);
  expect(drift()).toEqual(["  clean"]);
  installed("0123456789abcdef0123456789abcdef01234567");
  expect(drift()).toEqual([
    `  note: whetstone@raisedadead-plugins installed 0123456789ab is not in ${own} — fetch to compare it with origin/main`,
    "  clean",
  ]);
  git(own, "update-ref", "-d", "refs/remotes/origin/main");
  expect(drift()).toEqual([`  note: ${own} has no origin/main — fetch it to compare the installs`]);
});

test("the safeguard toggle warns unless both settings files hold false", () => {
  json(join(claude, "settings.json"), { ...SETTINGS, switchModelsOnFlag: true });
  put(join(home, ".bin", "claude-flag-audit.sh"), "#!/bin/sh\necho 'total 3 flag(s) last 7d 3'\n", 0o755);
  expect(section(run().out, "[warn 2/6]").split("\n").slice(1)).toEqual([
    "  WARN: switchModelsOnFlag != false in ~/.claude/settings.json (got: true) — safeguard flag will silently switch model; re-flip via /config",
    "  note: 3 safeguard flag(s) in last 7 days — claude-flag-audit.sh 7",
  ]);
  json(join(sub, ".settings.managed.json"), RUNTIME);
  rmSync(join(claude, "settings.json"));
  rmSync(join(home, ".bin", "claude-flag-audit.sh"));
  const r = run();
  expect(section(r.out, "[warn 2/6]").split("\n").slice(1)).toEqual([
    "  WARN: switchModelsOnFlag != false in ~/.dotfiles/dot_claude/.settings.managed.json (got: null) — safeguard flag will silently switch model; re-flip via /config",
    "  skip (~/.claude/settings.json missing)",
  ]);
  expect(r.code).toBe(0);
});

test("the rig gate re-tests the committed rig only on a new Claude Code version", () => {
  const types = join(claude, "mods", "rig", ".claude-plugin", "types", "claude-code", "index.d.ts");
  const verified = join(claude, "markers", "rig-verified-version");
  const log = join(claude, "markers", "rig-gate.log");
  stub("claude", 'case "$1" in --version) echo "9.9.2 (Claude Code)" ;; *) echo "claude $*" ;; esac');
  stub("bun", 'printf \'%s %s\\n\' "$PWD" "$*" >> "$DOCTOR_CTL/bun-calls"; echo "bun $*"; exit "$(cat "$DOCTOR_CTL/bun-rc" 2>/dev/null || echo 0)"');
  stub("bunx", "exit 0");
  const gate = () => section(run().out, "[warn 3/6]").split("\n").slice(1);

  put(types, "// Written by Claude Code 9.9.1.\nexport {};\n");
  put(verified, "9.9.1\n");
  expect(gate()).toEqual(["  clean (9.9.1 verified)"]);
  expect(existsSync(join(ctl, "bun-calls"))).toBe(false);

  put(types, "// Written by someone else\n");
  expect(gate()).toEqual(["  WARN: line 1 of ~/.claude/mods/rig/.claude-plugin/types/claude-code/index.d.ts names no Claude Code version"]);

  put(types, "// Written by Claude Code 9.9.2.\n");
  put(join(ctl, "bun-rc"), "1\n");
  expect(gate()).toEqual(["  WARN: the committed rig fails build, validate or tests on Claude Code 9.9.2; read ~/.claude/markers/rig-gate.log"]);
  expect(readFileSync(verified, "utf8")).toBe("9.9.1\n");
  expect(readFileSync(join(ctl, "bun-calls"), "utf8")).toMatch(/\/mods\/rig build\.ts\n$/);
  expect(readFileSync(log, "utf8")).toBe("bun build.ts\n");

  put(join(ctl, "bun-rc"), "0\n");
  expect(gate()).toEqual(["  clean (9.9.2 verified now)"]);
  expect(readFileSync(verified, "utf8")).toBe("9.9.2\n");
  expect(readFileSync(log, "utf8")).toBe("bun build.ts\nclaude plugin validate dist\nclaude plugin test dist\n");

  put(types, "// Written by Claude Code 9.9.3.\n");
  rmSync(join(bin, "bunx"));
  expect(gate()).toEqual(["  skip (bunx missing)"]);
});

test("release stores warn above two releases", () => {
  for (const name of ["r1", "r2", "r3"]) mkdirSync(join(home, ".codex", "packages", "app-server-daemon", "releases", name), { recursive: true });
  for (const name of ["r1", "r2"]) mkdirSync(join(home, ".pi", "agent", "install", "releases", name), { recursive: true });
  const lines = section(run().out, "[warn 4/6]").split("\n").slice(1);
  expect(lines.length).toBe(1);
  expect(lines[0]).toMatch(/^ {2}WARN: ~\/\.codex\/packages\/app-server-daemon\/releases holds 3 releases \(\S+\); keep only the newest two$/);
  const pi = join(base, "pi");
  mkdirSync(join(pi, "a"), { recursive: true });
  const r = run([], { env: { CODEX_RELEASES: join(base, "none"), PI_RELEASES: pi } });
  expect(section(r.out, "[warn 4/6]").split("\n").slice(1)).toEqual([`  skip (${base}/none missing)`, "  clean"]);
});

test("a link to a missing file warns", () => {
  link("/bin/sh", join(home, ".bin", "ok"));
  link(join(home, "missing"), join(home, ".bin", "gone"));
  const r = run();
  expect(section(r.out, "[warn 5/6]").split("\n").slice(1)).toEqual([
    `  WARN: ~/.bin/gone points to a missing ${home}/missing; reinstall the target or run its setup command`,
  ]);
  expect(r.code).toBe(0);
});

test("a skill link to a missing skill warns", () => {
  mkdirSync(join(home, ".agents", "skills", "ok"), { recursive: true });
  link("../../.agents/skills/ok", join(claude, "skills", "ok"));
  link("../../.agents/skills/gone", join(claude, "skills", "gone"));
  expect(section(run().out, "[warn 5/6]").split("\n").slice(1)).toEqual([
    "  WARN: ~/.claude/skills/gone points to a missing ../../.agents/skills/gone; reinstall the target or run its setup command",
  ]);
});

test("agent additions warn until they are removed or approved", () => {
  const rig = join(claude, "mods", "rig");
  const additions = join(src, "docs", "agent-additions.txt");
  const source = {
    switchModelsOnFlag: false,
    hooks: { Stop: [{ hooks: [{ type: "command", command: "ok" }] }] },
    enabledPlugins: { "good@m": true },
    extraKnownMarketplaces: { m: {} },
    env: { KEEP: "a" },
    mcpServers: { srv: { type: "http", url: "a" } },
  };
  json(join(sub, ".settings.managed.json"), source);
  json(join(claude, "settings.json"), source);
  put(join(sub, "CLAUDE.md"), "kernel\n");
  put(join(claude, "CLAUDE.md"), "kernel\n");
  put(join(sub, "mods", "rig", "hooks", "hooks.json"), "{}");
  put(join(rig, "hooks", "hooks.json"), "{}");
  put(join(src, "dot_pi", "agent", "mcp.json.tmpl"), '{"mcpServers":{"good":{"command":"x"}}}');
  json(join(home, ".claude.json"), { mcpServers: source.mcpServers, projects: {} }, 0o600);
  put(additions);
  mkdirSync(join(claude, "rules", "sub"), { recursive: true });
  mkdirSync(join(claude, "skills"), { recursive: true });
  mkdirSync(join(home, ".agents", "skills"), { recursive: true });
  mkdirSync(join(home, ".pi", "agent", "extensions"), { recursive: true });
  mkdirSync(join(home, ".codex", "rules"), { recursive: true });
  managed(join(claude, "settings.json"), join(claude, "agents", "a.md"), join(claude, "CLAUDE.md"), join(claude, "rules", "sub"), rig, join(rig, "hooks"), join(rig, "hooks", "hooks.json"));
  const head = "[warn 6/6] agent additions (Claude, Pi and Codex items outside the source and docs/agent-additions.txt)";
  expect(section(run().out, "[warn 6/6]")).toBe(`${head}\n  clean`);

  json(join(claude, "settings.json"), {
    switchModelsOnFlag: false,
    hooks: {
      Stop: [{ hooks: [{ type: "command", command: "ok" }] }, { matcher: "evil", hooks: [{ type: "command", command: "ok" }] }],
      FileChanged: [{ hooks: [{ type: "command", command: "evil" }] }],
    },
    enabledPlugins: { "good@m": true, "evil@m": true, "bad\u001bname@m": true },
    extraKnownMarketplaces: { m: {}, evil: {} },
    statusLine: { command: "evil" },
    fileSuggestion: { command: "evil" },
    subagentStatusLine: { command: "evil-sub" },
    env: { KEEP: "b", EVIL_URL: "x" },
    mcpServers: { srv: { type: "http", url: "b" } },
  });
  json(join(home, ".claude.json"), { mcpServers: { ...source.mcpServers, "evil-user": {} }, projects: { "/p": { mcpServers: { evil: {} } } } }, 0o600);
  put(join(home, "plugin", "hooks", "hooks.json"), '{"hooks":{"Stop":[]},"modules":["./evil.tsx"]}');
  put(join(home, "plugin", ".claude-plugin", "plugin.json"), '{"mcpServers":{"evil-manifest":{}}}');
  put(join(home, "plugin", ".mcp.json"), '{"mcpServers":{"evil-file":{}}}');
  json(join(claude, "plugins", "installed_plugins.json"), { plugins: { "evil@m": [{ installPath: join(home, "none") }, { installPath: join(home, "plugin") }] } });
  link("../../.agents/skills/evil", join(claude, "skills", "evil"));
  mkdirSync(join(home, ".agents", "skills", "evil"));
  put(join(claude, "evil.py"), "#!/bin/sh\n");
  link("/tmp/x", join(claude, "evil-link.sh"));
  put(join(claude, "CLAUDE.md"), "kernel\ninjected\n");
  put(join(claude, "rules", "sub", "evil.md"));
  put(join(rig, "hooks", "hooks.json"), '{"modules":["evil"]}');
  put(join(home, ".pi", "agent", "extensions", "evil.ts"));
  put(join(home, ".pi", "agent", "SYSTEM.md"));
  put(join(home, ".pi", "agent", "settings.json"), '{"packages":["npm:evil"],"extensions":["/tmp/evil.ts"],"skills":["/tmp/evilskill"]}');
  put(join(home, ".pi", "agent", "mcp.json"), '{"mcpServers":{"good":{},"command":{}}}');
  put(
    join(home, ".codex", "config.toml"),
    "notify = [\n  '/bin/evil',\n  \"arg\",\n]\n[marketplaces.evil]\n[mcp_servers.\"evil.dot\"] # note\n  [mcp_servers.evil_indent]\n[[hooks.Stop]]\n[plugins.'lit@other']\n[agents.evil]\n",
  );
  put(join(home, ".codex", "AGENTS.md"));
  put(join(home, ".codex", "AGENTS.override.md"));
  put(join(home, ".codex", "rules", "evil.rules"));
  const r = run();
  const items = [
    "claude-hook FileChanged[]: evil",
    "claude-hook Stop[evil]: ok",
    "claude-plugin evil@m",
    "claude-plugin badname@m",
    "claude-marketplace evil",
    "claude-statusline evil",
    "claude-statusline evil-sub",
    "claude-file-suggestion evil",
    "claude-env EVIL_URL",
    "claude-env KEEP",
    "claude-mcp srv",
    "claude-mcp evil-user",
    "claude-project-mcp evil",
    "claude-plugin-hook evil@m Stop",
    "claude-plugin-hook evil@m ./evil.tsx",
    "claude-plugin-mcp evil@m evil-manifest",
    "claude-plugin-mcp evil@m evil-file",
    "claude-skills evil",
    "claude-rules sub/evil.md",
    "claude-script evil.py",
    "claude-script evil-link.sh",
    "instructions .claude/CLAUDE.md",
    "instructions .claude/mods/rig/hooks/hooks.json",
    "instructions .pi/agent/SYSTEM.md",
    "shared-skills evil",
    "pi-extensions evil.ts",
    "pi-packages npm:evil",
    "pi-extensions /tmp/evil.ts",
    "pi-skills /tmp/evilskill",
    "pi-mcp command",
    'codex-notify "/bin/evil", "arg"',
    "codex-marketplace evil",
    "codex-mcp evil.dot",
    "codex-mcp evil_indent",
    "codex-plugin lit@other",
    "codex-agent evil",
    "codex-hooks config",
    "codex-rules evil.rules",
    "codex-instructions AGENTS.md",
    "codex-instructions AGENTS.override.md",
  ];
  const lines = section(r.out, "[warn 6/6]").split("\n").slice(1);
  expect(lines).toEqual([...items].sort().map(item => `  WARN: agent addition: ${item} - remove it, or add this item to docs/agent-additions.txt`));
  expect(r.out).not.toContain("\u001b");

  put(additions, `${items.join("\n")}\n`);
  expect(section(run().out, "[warn 6/6]")).toBe(`${head}\n  clean`);

  put(join(claude, "settings.json"), "not json");
  expect(section(run().out, "[warn 6/6]")).toContain(
    "\n  WARN: agent addition: unreadable .claude/settings.json - remove it, or add this item to docs/agent-additions.txt",
  );
  put(join(ctl, "managed"), "");
  expect(section(run().out, "[warn 6/6]")).toBe(`${head}\n  WARN: agent addition: check skipped (chezmoi managed list empty)`);
});

test("--rewake in a background session exits 0 and leaves the marker", () => {
  put(marker(), "stale\n");
  put(join(claude, "notes.md"));
  const r = run(["--rewake"], { cwd: src, env: { CLAUDE_JOB_DIR: join(base, "job") } });
  expect(r).toEqual({ code: 0, out: "", err: "" });
  expect(readFileSync(marker(), "utf8")).toBe("stale\n");
});

test("--rewake with issues wakes the model and records the warnings", () => {
  put(join(claude, "notes.md"));
  link(join(home, "missing"), join(home, ".bin", "gone"));
  const r = run(["--rewake"], { cwd: src });
  expect(r.code).toBe(2);
  expect(r.out).toBe("");
  expect(r.err).toStartWith("chezmoi-claude-doctor: issues found. Run ~/.bin/chezmoi-claude-doctor");
  expect(r.err).toContain(`\n[3/5] shape (unmanaged top-level *.{md|toml|yaml|yml|kdl|ini})\n  ORPHAN: ${claude}/notes.md\n`);
  expect(r.err).toEndWith("[warn 6/6] agent additions (Claude, Pi and Codex items outside the source and docs/agent-additions.txt)\n  clean\n");
  expect(readFileSync(marker(), "utf8")).toBe(`~/.bin/gone points to a missing ${home}/missing; reinstall the target or run its setup command\n`);
});

test("--rewake with warnings only stays silent and records them", () => {
  link(join(home, "missing"), join(home, ".bin", "gone"));
  const r = run(["--rewake"], { cwd: src });
  expect(r).toEqual({ code: 0, out: "", err: "" });
  expect(readFileSync(marker(), "utf8")).toBe(`~/.bin/gone points to a missing ${home}/missing; reinstall the target or run its setup command\n`);
});

test("--rewake on a clean machine removes the marker", () => {
  put(marker(), "old\n");
  expect(run(["--rewake"], { cwd: src })).toEqual({ code: 0, out: "", err: "" });
  expect(existsSync(marker())).toBe(false);
});

test("--rewake runs in a source submodule and in a linked worktree", () => {
  put(join(claude, "notes.md"));
  expect(run(["--rewake"], { cwd: sub }).code).toBe(2);
  const tree = join(base, "tree");
  git(src, "worktree", "add", "-q", tree);
  expect(run(["--rewake"], { cwd: tree }).code).toBe(2);
});

test("--rewake with an uninitialised submodule wakes the model", () => {
  git(src, "submodule", "deinit", "-q", "-f", "dot_claude");
  put(marker(), "old\n");
  const r = run(["--rewake"], { cwd: src });
  expect(r.code).toBe(2);
  expect(r.err).toContain(`dot_claude submodule not initialised: git -C ${src} submodule update --init`);
  expect(existsSync(marker())).toBe(false);
});

test("--rewake outside the source updates only the agent addition lines", () => {
  put(join(claude, "notes.md"));
  put(join(home, ".codex", "AGENTS.md"));
  put(marker(), "other warning\nagent addition: old\n");
  const outside = join(base, "outside");
  expect(run(["--rewake"], { cwd: outside })).toEqual({ code: 0, out: "", err: "" });
  expect(readFileSync(marker(), "utf8")).toBe(
    "other warning\nagent addition: codex-instructions AGENTS.md - remove it, or add this item to docs/agent-additions.txt\n",
  );
  rmSync(join(home, ".codex", "AGENTS.md"));
  put(marker(), "agent addition: old\n");
  expect(run(["--rewake"], { cwd: outside })).toEqual({ code: 0, out: "", err: "" });
  expect(existsSync(marker())).toBe(false);
});

test("--rewake outside the source keeps the other warnings when no addition is left", () => {
  put(marker(), "other warning\nagent addition: old\n");
  expect(run(["--rewake"], { cwd: join(base, "outside") })).toEqual({ code: 0, out: "", err: "" });
  expect(readFileSync(marker(), "utf8")).toBe("other warning\n");
});

test("--rewake obeys the cwd in the stdin payload", () => {
  put(join(claude, "notes.md"));
  const outside = join(base, "outside");
  expect(run(["--rewake"], { cwd: src, stdin: JSON.stringify({ cwd: outside }) })).toEqual({ code: 0, out: "", err: "" });
  expect(run(["--rewake"], { cwd: outside, stdin: JSON.stringify({ cwd: src }) }).code).toBe(2);
});

test("--rewake from a deleted cwd exits 0 and stays silent", () => {
  const gone = join(base, "gone");
  mkdirSync(gone);
  const proc = Bun.spawnSync(["bash", "-c", 'cd "$1" && rmdir "$1" && shift && exec "$@"', "_", gone, ...doctor, "--rewake"], {
    env: baseEnv(),
    stdin: "ignore",
  });
  expect({ code: proc.exitCode, out: proc.stdout.toString(), err: proc.stderr.toString() }).toEqual({ code: 0, out: "", err: "" });
});

test("--rewake outside the source stays silent without chezmoi", () => {
  rmSync(join(bin, "chezmoi"));
  expect(run(["--rewake"], { cwd: join(base, "outside") })).toEqual({ code: 0, out: "", err: "" });
});

test("--rewake does not wait for a stdin that stays open", async () => {
  const env: Record<string, string> = baseEnv();
  const proc = Bun.spawn([...doctor, "--rewake"], { cwd: join(base, "outside"), env, stdin: "pipe", stdout: "pipe", stderr: "pipe" });
  const started = Date.now();
  const code = await Promise.race([proc.exited, Bun.sleep(5000).then(() => "timeout")]);
  proc.kill();
  expect(code).toBe(0);
  expect(Date.now() - started).toBeLessThan(5000);
});
