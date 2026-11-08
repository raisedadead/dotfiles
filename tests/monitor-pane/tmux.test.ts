import { afterAll, beforeAll, expect, test } from "bun:test";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve } from "node:path";

const SCRIPT = resolve(import.meta.dir, "../../dot_claude/skills/cmd-monitor-pane/scripts/executable_watch-pane.ts");
const SOCKET = `mon-test-${process.pid}`;
const HEADER = /^(?:error|end|match|prompt|lost)(?:,(?:error|end|match|prompt|lost))* · /;
const state = mkdtempSync(`${tmpdir()}/watch-pane-test-`);

let pane = "";
let tmuxEnv = "";

function tmux(...args: string[]): string {
  const result = Bun.spawnSync(["tmux", "-L", SOCKET, ...args]);
  return result.stdout.toString().trim();
}

function type(text: string): void {
  tmux("send-keys", "-t", pane, "-l", text);
  tmux("send-keys", "-t", pane, "Enter");
}

class Watcher {
  readonly lines: string[] = [];
  readonly child = Bun.spawn(["bun", "--no-env-file", "--config=/dev/null", SCRIPT, pane], {
    stdout: "pipe",
    stderr: "pipe",
    env: { PATH: process.env.PATH ?? "", HOME: process.env.HOME ?? "", TMUX: tmuxEnv, TMPDIR: state },
  });
  readonly done = this.read();

  async read(): Promise<void> {
    const decoder = new TextDecoder();
    let rest = "";
    for await (const chunk of this.child.stdout) {
      rest += decoder.decode(chunk);
      const parts = rest.split("\n");
      rest = parts.pop() ?? "";
      this.lines.push(...parts);
    }
  }

  events(): string[][] {
    const found: string[][] = [];
    for (const line of this.lines) {
      if (HEADER.test(line)) found.push([line]);
      else found.at(-1)?.push(line);
    }
    return found;
  }

  async until(check: () => boolean, ms: number): Promise<boolean> {
    for (const end = Date.now() + ms; Date.now() < end; ) {
      if (check()) return true;
      await Bun.sleep(200);
    }
    return check();
  }

  has(text: string): boolean {
    return this.lines.some((line) => line.includes(text));
  }
}

beforeAll(() => {
  const shell = ["env", "-i", "PATH=/usr/bin:/bin:/opt/homebrew/bin", "HOME=/tmp", "TERM=xterm-256color", "PS1=$ "];
  tmux("-f", "/dev/null", "new-session", "-d", "-s", "t", "-x", "160", "-y", "40", ...shell, "bash", "--norc", "--noprofile");
  tmux("new-window", "-d", "-t", "t");
  pane = tmux("display-message", "-p", "-t", "t:0.0", "#{pane_id}");
  tmuxEnv = tmux("display-message", "-p", "-t", pane, "#{socket_path},#{pid},0");
});

afterAll(() => {
  tmux("kill-server");
  rmSync(state, { recursive: true, force: true });
});

test(
  "the watcher wakes on errors, prompts and run ends, keeps its place across a re-arm, and reports pane death",
  async () => {
    let watcher = new Watcher();
    await Bun.sleep(1500);

    type('for i in 1 2; do seq 1 25; done; echo "ERROR: after repeat"');
    expect(await watcher.until(() => watcher.has("ERROR: after repeat"), 15000)).toBe(true);

    const spinner = [
      "import sys, time",
      "for i in range(60):",
      "    sys.stdout.write('\\rtick %d' % i); sys.stdout.flush(); time.sleep(0.2)",
      "    i == 5 and print('\\nfatal: during spinner', flush=True)",
    ].join("\n");
    type(`python3 -c "${spinner}"`);
    expect(await watcher.until(() => watcher.has("fatal: during spinner"), 30000)).toBe(true);
    const spun = await watcher.until(() => watcher.events().some(([head]) => head?.startsWith("end") === true), 20000);
    expect(spun).toBe(true);

    watcher.child.kill("SIGTERM");
    await watcher.done;
    type('echo "ERROR: while down"');
    await Bun.sleep(1000);
    watcher = new Watcher();
    expect(await watcher.until(() => watcher.has("ERROR: while down"), 15000)).toBe(true);
    await Bun.sleep(3000);

    const before = watcher.events().length;
    type("python3 -c \"import time\nfor i in range(24): print('ok step', i, flush=True); time.sleep(0.5)\"");
    await Bun.sleep(12000);
    expect(await watcher.until(() => watcher.events().length > before, 10000)).toBe(true);
    await Bun.sleep(4000);
    const healthy = watcher.events().slice(before);
    expect(healthy.length).toBe(1);
    expect(healthy[0]?.[0]).toMatch(/^end · .* · \S*python\S* .* ran \d+s$/i);

    const chained = watcher.events().length;
    type("echo '===== 3 passed in 0.10s =====' && sleep 20 && echo deployed");
    expect(await watcher.until(() => watcher.events().length > chained, 10000)).toBe(true);
    expect(await watcher.until(() => watcher.events().length > chained + 1, 30000)).toBe(true);
    expect(watcher.events().at(-1)?.[0]).toMatch(/^end · .* · sleep 20 ran 2\ds$/);

    type("python3 -c \"input('Continue? [y/N] ')\"");
    expect(await watcher.until(() => watcher.lines.some((line) => line.startsWith("prompt ·")), 15000)).toBe(true);
    type("y");
    await Bun.sleep(3000);

    tmux("kill-pane", "-t", pane);
    await watcher.done;
    expect(watcher.lines.at(-1)).toBe("pane gone");
    expect(await watcher.child.exited).toBe(0);
  },
  180000,
);
