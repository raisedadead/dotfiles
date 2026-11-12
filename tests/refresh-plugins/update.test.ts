import { afterEach, beforeEach, expect, test } from "bun:test";
import { chmodSync, existsSync, mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { CLAUDE_LOG, calls, cleanup, type Fixture, fixture, green, installs, json, MINE, marketplace, run, section, stub, version } from "./harness";

let fx: Fixture;

beforeEach(() => {
  fx = fixture();
  green(fx);
});

afterEach(() => {
  cleanup(fx);
});

const OLD = "a".repeat(40);
const NEW = "b".repeat(40);
const STALE = `install sha ${OLD.slice(0, 12)}, marketplace pins ${NEW.slice(0, 12)}`;
const settingsPath = () => join(fx.claude, "settings.json");
const installedPath = () => join(fx.plugins, "installed_plugins.json");

const drifted = (...names: string[]) => marketplace(fx, MINE, names.map((name) => ({ name, source: { source: "github", repo: "x/y", sha: NEW } })));

const record = (name: string, extra: Record<string, unknown> = {}) => {
  const dir = version(fx, MINE, name, "1.0.0");
  writeFileSync(join(dir, "a.txt"), `${name}-build`);
  return { installPath: dir, version: "1.0.0", gitCommitSha: OLD, ...extra };
};

const claude = (body: string) =>
  stub(
    fx,
    "claude",
    `${CLAUDE_LOG}
installed="$HOME/.claude/plugins/installed_plugins.json"
settings="$HOME/.claude/settings.json"
rewrite() { local file="$1"; shift; local out; out=$(jq "$@" "$file") && printf '%s\\n' "$out" > "$file"; }
${body}
exit 0`,
  );

const changing = () => calls(fx).filter((call) => /\|plugin (un)?install /.test(call));

test("update fetches each marketplace once, updates each plugin in its scope, and keeps only the updated-from lines", () => {
  const proj = join(fx.home, "proj");
  const nope = join(fx.home, "nope");
  mkdirSync(proj);
  installs(fx, {
    "a@m1": [{ installPath: version(fx, "m1", "a", "1.0.0"), version: "1.0.0" }],
    "c@m1": [{ installPath: version(fx, "m1", "c", "1.0.0"), version: "1.0.0" }],
    "b@m2": [{ installPath: version(fx, "m2", "b", "1.0.0"), version: "1.0.0" }],
    "d@m1": [{ installPath: version(fx, "m1", "d", "1.0.0"), version: "1.0.0", scope: "project", projectPath: proj }],
    "e@m1": [{ installPath: version(fx, "m1", "e", "1.0.0"), version: "1.0.0", scope: "local", projectPath: nope }],
  });
  claude(`case "$*" in
"plugin update a@m1 --scope user") printf 'Checking a@m1\\n\\u2714 Plugin "a" updated from 1.0.0 to 1.1.0 at user scope\\ntail updated from x' ;;
"plugin marketplace update m2") exit 1 ;;
esac`);

  const r = run(fx, "all");

  expect(r.code).toBe(0);
  expect(section(r.out, "UPDATE", "FORCE")).toBe(
    [
      "UPDATE",
      "  marketplace: m1",
      "  marketplace: m2",
      "    WARN marketplace update failed: m2",
      "  plugin: a@m1 (was 1.0.0)",
      "    updated from 1.0.0 to 1.1.0 at user scope",
      "    updated from x  plugin: c@m1 (was 1.0.0)",
      "  plugin: b@m2 (was 1.0.0)",
      "  plugin: d@m1 (was 1.0.0)",
      "  plugin: e@m1 (was 1.0.0)",
      "",
    ].join("\n"),
  );
  expect(r.err).toBe("");
  expect(calls(fx)).toEqual([
    `${fx.home}|plugin marketplace update ${MINE}`,
    `${fx.home}|plugin marketplace update m1`,
    `${fx.home}|plugin marketplace update m2`,
    `${fx.home}|plugin update a@m1 --scope user`,
    `${fx.home}|plugin update c@m1 --scope user`,
    `${fx.home}|plugin update b@m2 --scope user`,
    `${proj}|plugin update d@m1 --scope project`,
  ]);
});

test("a drifted install is reinstalled and its enabled flag is put back as it was", () => {
  drifted("on", "off", "never", "same");
  installs(fx, {
    [`on@${MINE}`]: [record("on")],
    [`off@${MINE}`]: [record("off")],
    [`never@${MINE}`]: [record("never")],
    [`same@${MINE}`]: [record("same", { gitCommitSha: NEW })],
    [`unknown@${MINE}`]: [record("unknown")],
  });
  writeFileSync(settingsPath(), JSON.stringify({ theme: "dark", enabledPlugins: { [`on@${MINE}`]: true, [`off@${MINE}`]: false } }));
  chmodSync(settingsPath(), 0o640);
  claude(`[[ "$1 $2" == "plugin install" ]] && rewrite "$settings" --arg k "$3" '.enabledPlugins[$k] = true'`);

  const r = run(fx, "all");

  expect(r.code).toBe(0);
  expect(r.err).toBe("");
  expect(section(r.out, "FORCE", "BURST")).toBe(
    [
      "FORCE",
      ...["on", "off", "never"].flatMap((name) => [`  stale: ${name}@${MINE} (${STALE})`, `    reinstalled ${name}@${MINE}`]),
      "  forced 3 reinstall(s), 0 rolled back, 0 left uninstalled",
      "",
    ].join("\n"),
  );
  expect(readFileSync(settingsPath(), "utf8")).toBe(`${JSON.stringify({ theme: "dark", enabledPlugins: { [`on@${MINE}`]: true, [`off@${MINE}`]: false } }, null, 2)}\n`);
  expect(statSync(settingsPath()).mode & 0o777).toBe(0o640);
  expect(changing()).toEqual(
    ["on", "off", "never"].flatMap((name) => [
      `${fx.home}|plugin uninstall ${name}@${MINE} --scope user --keep-data -y`,
      `${fx.home}|plugin install ${name}@${MINE} --scope user -y`,
    ]),
  );
  expect(readdirSync(fx.tmp)).toEqual([]);
});

test("an empty enabledPlugins list in the snapshot counts as no flag, so the reinstall drops the flag", () => {
  drifted("x");
  installs(fx, { [`x@${MINE}`]: [record("x")] });
  writeFileSync(settingsPath(), JSON.stringify({ enabledPlugins: [] }));
  claude(`[[ "$1 $2" == "plugin install" ]] && rewrite "$settings" --arg k "$3" '.enabledPlugins = {($k): true}'`);

  const r = run(fx, "all");

  expect(section(r.out, "FORCE", "BURST")).toBe(
    ["FORCE", `  stale: x@${MINE} (${STALE})`, `    reinstalled x@${MINE}`, "  forced 1 reinstall(s), 0 rolled back, 0 left uninstalled", ""].join("\n"),
  );
  expect(readFileSync(settingsPath(), "utf8")).toBe('{\n  "enabledPlugins": {}\n}\n');
});

test("a failed reinstall puts the previous build, its record and its flag back", () => {
  drifted("x", "y");
  const original = { [`x@${MINE}`]: [record("x")], [`y@${MINE}`]: [record("y")] };
  installs(fx, original);
  chmodSync(installedPath(), 0o604);
  writeFileSync(settingsPath(), JSON.stringify({ enabledPlugins: { [`x@${MINE}`]: false, [`y@${MINE}`]: true } }));
  claude(`case "$1 $2 $3" in
"plugin uninstall x@${MINE}")
  rm -rf "$HOME/.claude/plugins/cache/${MINE}/x/1.0.0"
  rewrite "$installed" --arg k "$3" 'del(.plugins[$k])'
  rewrite "$settings" --arg k "$3" 'del(.enabledPlugins[$k])' ;;
"plugin install "*) exit 1 ;;
esac`);

  const r = run(fx, "all");

  expect(r.code).toBe(0);
  expect(r.err).toBe("");
  expect(section(r.out, "FORCE", "BURST")).toBe(
    [
      "FORCE",
      ...["x", "y"].flatMap((name) => [
        `  stale: ${name}@${MINE} (${STALE})`,
        `    RESTORED ${name}@${MINE}: the reinstall failed, the previous build is back in place`,
      ]),
      "  forced 0 reinstall(s), 2 rolled back, 0 left uninstalled",
      "",
    ].join("\n"),
  );
  expect(readFileSync(join(fx.cache, MINE, "x", "1.0.0", "a.txt"), "utf8")).toBe("x-build");
  expect(readFileSync(join(fx.cache, MINE, "y", "1.0.0", "a.txt"), "utf8")).toBe("y-build");
  expect(JSON.parse(readFileSync(installedPath(), "utf8")).plugins).toEqual(original);
  expect(statSync(installedPath()).mode & 0o777).toBe(0o604);
  expect(JSON.parse(readFileSync(settingsPath(), "utf8"))).toEqual({ enabledPlugins: { [`y@${MINE}`]: true, [`x@${MINE}`]: false } });
  expect(readdirSync(fx.tmp)).toEqual([]);
});

test("a failed uninstall leaves the install untouched and tries no install", () => {
  drifted("x");
  installs(fx, { [`x@${MINE}`]: [record("x")] });
  writeFileSync(settingsPath(), "{}");
  claude(`[[ "$1 $2" == "plugin uninstall" ]] && exit 1`);

  const r = run(fx, "all");

  expect(section(r.out, "FORCE", "BURST")).toBe(
    ["FORCE", `  stale: x@${MINE} (${STALE})`, `    WARN uninstall failed, install untouched: x@${MINE}`, "  forced 0 reinstall(s), 0 rolled back, 0 left uninstalled", ""].join("\n"),
  );
  expect(changing()).toEqual([`${fx.home}|plugin uninstall x@${MINE} --scope user --keep-data -y`]);
  expect(readdirSync(fx.tmp)).toEqual([]);
});

test("force refuses an install it cannot place, scope, or snapshot whole", () => {
  drifted("w", "x", "y", "z");
  const outside = join(fx.home, "elsewhere", "w", "1.0.0");
  mkdirSync(outside, { recursive: true });
  const proj = join(fx.home, "proj");
  json(join(proj, ".claude", "settings.local.json"), {});
  const z = record("z", { scope: "local", projectPath: proj });
  writeFileSync(join(z.installPath, "locked"), "x");
  chmodSync(join(z.installPath, "locked"), 0o000);
  installs(fx, {
    [`w@${MINE}`]: [{ installPath: outside, version: "1.0.0", gitCommitSha: OLD }],
    [`y@${MINE}`]: [record("y", { scope: "project" })],
    [`x@${MINE}`]: [record("x")],
    [`z@${MINE}`]: [z],
  });

  const r = run(fx, "all");

  expect(section(r.out, "FORCE", "BURST")).toBe(
    [
      "FORCE",
      `    REFUSING w@${MINE}: install path resolves outside ${fx.cache}`,
      `    REFUSING y@${MINE}: project scope, but its project (none) is not a directory`,
      `  stale: x@${MINE} (${STALE})`,
      `    REFUSING x@${MINE}: ${settingsPath()} is missing, so its enabledPlugins flag could not be snapshotted`,
      `  stale: z@${MINE} (${STALE})`,
      `    REFUSING z@${MINE}: the install could not be snapshotted whole, so a rollback could not be trusted`,
      "  forced 0 reinstall(s), 0 rolled back, 0 left uninstalled",
      "",
    ].join("\n"),
  );
  expect(changing()).toEqual([]);
  expect(readdirSync(fx.tmp)).toEqual([]);
});

test("a rollback that fails too keeps the snapshot and prints shell-quoted commands to recover", () => {
  drifted("x", "y");
  const proj = join(fx.home, "my proj");
  json(join(proj, ".claude", "settings.json"), {});
  const xDir = version(fx, MINE, "x", "1.0 beta");
  writeFileSync(join(xDir, "a.txt"), "x-build");
  const y = record("y", { scope: "project", projectPath: proj });
  installs(fx, { [`x@${MINE}`]: [{ installPath: xDir, version: "1.0 beta", gitCommitSha: OLD }], [`y@${MINE}`]: [y] });
  writeFileSync(settingsPath(), "{}");
  claude(`case "$1 $2 $3" in
"plugin uninstall x@${MINE}") rm -rf "${xDir}"; echo '[]' > "$installed" ;;
"plugin install "*) exit 1 ;;
esac`);

  const r = run(fx, "all");

  const backups = [...r.out.matchAll(/The build is kept at (\S+)\/install/g)].map((m) => m[1]);
  expect(backups).toHaveLength(2);
  const [bx, by] = backups;
  const yDir = y.installPath;
  expect(section(r.out, "FORCE", "BURST")).toBe(
    [
      "FORCE",
      `  stale: x@${MINE} (${STALE})`,
      `    LOST x@${MINE}: uninstalled, the reinstall failed, and the rollback failed too.`,
      `      The build is kept at ${bx}/install`,
      "      Copy it back with:",
      `      rm -rf ${xDir.replace(" ", "\\ ")} && cp -R ${bx}/install ${xDir.replace(" ", "\\ ")}`,
      "      Or let the CLI fetch it again — which fails until whatever stopped the reinstall is fixed:",
      `      claude plugin install x@${MINE} --scope user`,
      `  stale: y@${MINE} (${STALE})`,
      `    LOST y@${MINE}: uninstalled, the reinstall failed, and the rollback failed too.`,
      `      The build is kept at ${by}/install`,
      `      and what was installed at ${yDir} was moved to ${by}/replaced, so that path may now be an empty directory.`,
      "      Copy it back with:",
      `      rm -rf ${yDir} && cp -R ${by}/install ${yDir}`,
      "      Or let the CLI fetch it again — which fails until whatever stopped the reinstall is fixed:",
      `      cd ${proj.replace(" ", "\\ ")} && claude plugin install y@${MINE} --scope project`,
      "  forced 0 reinstall(s), 0 rolled back, 2 left uninstalled",
      "",
    ].join("\n"),
  );
  expect(bx.startsWith(join(fx.tmp, "refresh-plugins."))).toBe(true);
  expect(readFileSync(join(bx, "install", "a.txt"), "utf8")).toBe("x-build");
  expect(readFileSync(join(by, "replaced", "a.txt"), "utf8")).toBe("y-build");
  expect(r.err).toContain(`restore: no snapshot of x@${MINE} to put back\n`);
  expect(r.err).toContain(`restore: no snapshot of y@${MINE} to put back\n`);
});

const interrupted = (uninstall: string) => {
  drifted("x");
  installs(fx, { [`x@${MINE}`]: [record("x")] });
  writeFileSync(settingsPath(), "{}");
  claude(`case "$1 $2 $3" in
"plugin uninstall x@${MINE}") ${uninstall}; rm -rf "$HOME/.claude/plugins/cache/${MINE}/x/1.0.0" ;;
"plugin install "*) exit 1 ;;
esac`);
  const r = run(fx, "all");
  expect(r.code).toBe(0);
  expect(r.out).toContain(`    RESTORED x@${MINE}: the reinstall failed, the previous build is back in place\n`);
  expect(existsSync(join(fx.cache, MINE, "x", "1.0.0", "a.txt"))).toBe(true);
  expect(readdirSync(fx.tmp)).toEqual([]);
  return r;
};

const INTERRUPTED = () =>
  new RegExp(`^\\n {4}INTERRUPTED: x@${MINE} is uninstalled right now\\. This run puts it back if it continues; if it does not, restore from ${fx.tmp}/refresh-plugins\\.\\w+\\n$`);

test("a signal during the rollback names the snapshot on stderr, and the run goes on", () => {
  stub(fx, "cp", `[[ "$1" == -R && "$2" == */refresh-plugins.*/install && "$3" != */refresh-plugins.* ]] && { kill -TERM $PPID; sleep 0.3; }\nexec /bin/cp "$@"`);
  const r = interrupted("true");
  expect(r.err).toMatch(INTERRUPTED());
});

test("a signal during the uninstall call names the snapshot on stderr, and the run goes on", () => {
  const r = interrupted("kill -TERM $PPID; sleep 0.3");
  expect(r.err).toMatch(INTERRUPTED());
});
