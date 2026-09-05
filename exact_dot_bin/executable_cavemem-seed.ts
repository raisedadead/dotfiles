#!/usr/bin/env bun
/**
 * cavemem-seed — replay archived Claude Code conversations into cavemem.
 *
 * Source: ~/.config/superpowers/conversation-archive/<cwd-encoded>/<sessionId>.jsonl
 * Output: JSONL formatted for `cavemem import` (one session line + N observation lines).
 *
 * Privacy:
 *   - skip sessions whose cwd matches `privacy.excludePatterns` in ~/.cavemem/settings.json
 *   - strip <private>...</private> blocks from content (mirror live hook)
 *   - redact common secret patterns (AWS keys, GitHub tokens, generic API keys) when
 *     `privacy.redactSecrets=true` in settings
 *
 * Caveats:
 *   - `cavemem import` writes to the live DB regardless of env vars. Backup ~/.cavemem/data.db
 *     before running `cavemem import <out>`.
 *   - FTS5 triggers do NOT fire on bulk import — run `cavemem reindex` afterwards.
 *
 * Usage:
 *   cavemem-seed                       # full run, write /tmp/cavemem-seed-<ts>.jsonl
 *   cavemem-seed --limit 10            # process first 10 files only
 *   cavemem-seed --out /tmp/foo.jsonl  # custom output path
 *   cavemem-seed --archive <dir>       # custom archive root
 *   cavemem-seed --import              # auto-invoke `cavemem import` after writing (DANGEROUS)
 *   cavemem-seed --dry-run             # parse + count, no write
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { Glob } from "bun";

// ---- types -------------------------------------------------------------

type Settings = {
  privacy?: {
    excludePatterns?: string[];
    redactSecrets?: boolean;
  };
};

type ArchiveTurn = {
  type: string;
  sessionId?: string;
  cwd?: string;
  timestamp?: string;
  message?: {
    role?: string;
    content?: string | Array<Record<string, any>>;
  };
  toolUseResult?: any;
};

type SessionRow = {
  type: "session";
  id: string;
  ide: "claude-code";
  cwd: string;
  started_at: number;
  ended_at?: number;
};

type ObservationRow = {
  type: "observation";
  session_id: string;
  kind: "user_prompt" | "assistant" | "tool_use" | "tool_result" | "thinking";
  content: string;
  ts: number;
  intensity: "full";
  compressed: 0 | 1;
  metadata?: string;
};

type Stats = {
  filesScanned: number;
  filesSkippedNoSession: number;
  sessionsSkippedExcluded: number;
  sessionsEmitted: number;
  observationsEmitted: number;
  observationsSkippedEmpty: number;
  observationsSkippedUnknownType: number;
  redactionsApplied: number;
  privateBlocksStripped: number;
  byKind: Record<string, number>;
};

// ---- args --------------------------------------------------------------

function parseArgs() {
  const argv = process.argv.slice(2);
  const args: {
    limit?: number;
    out?: string;
    archive?: string;
    import?: boolean;
    dryRun?: boolean;
  } = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--limit") args.limit = Number(argv[++i]);
    else if (a === "--out") args.out = argv[++i];
    else if (a === "--archive") args.archive = argv[++i];
    else if (a === "--import") args.import = true;
    else if (a === "--dry-run") args.dryRun = true;
    else if (a === "--help" || a === "-h") {
      console.log(
        "usage: cavemem-seed [--limit N] [--out PATH] [--archive PATH] [--import] [--dry-run]",
      );
      process.exit(0);
    } else {
      console.error(`unknown flag: ${a}`);
      process.exit(2);
    }
  }
  return args;
}

// ---- privacy -----------------------------------------------------------

/** convert a glob like `**\/.env*` to a regex matching against full path */
function globToRegex(glob: string): RegExp {
  // Compile a glob to a JS regex anchored ^...$.
  //
  // Semantics (gitignore-ish):
  //   `**`            => ".*"               (zero or more chars across `/`)
  //   `*`             => "[^/]*"            (one segment, no slashes)
  //   `?`             => "[^/]"
  //   `/**` (suffix)  => "(/.*)?"           (the dir itself OR descendants)
  //   `**/` (prefix)  => "(.*/)?"           (root OR any dir prefix)
  //
  // The /** suffix rule is the critical fix: `**/.dotfiles/**` now
  // matches both `/Users/foo/.dotfiles` AND `/Users/foo/.dotfiles/sub`.
  let re = "";
  let i = 0;
  // strip a trailing `/**` and remember to append (/.*)? at the end
  let suffixOptional = false;
  let glob2 = glob;
  if (glob2.endsWith("/**")) {
    glob2 = glob2.slice(0, -3);
    suffixOptional = true;
  }
  // strip a leading `**/` similarly
  let prefixOptional = false;
  if (glob2.startsWith("**/")) {
    glob2 = glob2.slice(3);
    prefixOptional = true;
  }
  while (i < glob2.length) {
    const c = glob2[i];
    if (c === "*" && glob2[i + 1] === "*") {
      re += ".*";
      i += 2;
    } else if (c === "*") {
      re += "[^/]*";
      i++;
    } else if (c === "?") {
      re += "[^/]";
      i++;
    } else if (".+^$()|[]{}\\".includes(c)) {
      re += "\\" + c;
      i++;
    } else {
      re += c;
      i++;
    }
  }
  const head = prefixOptional ? "(.*/)?" : "";
  const tail = suffixOptional ? "(/.*)?" : "";
  return new RegExp("^" + head + re + tail + "$");
}

function compileExcludes(patterns: string[]): RegExp[] {
  return patterns.map(globToRegex);
}

function isExcluded(cwd: string, excludes: RegExp[]): boolean {
  if (!cwd || cwd === "<unknown>") return false;
  return excludes.some((r) => r.test(cwd));
}

const PRIVATE_BLOCK = /<private>[\s\S]*?<\/private>/g;

const SECRET_PATTERNS: Array<[RegExp, string]> = [
  // AWS access key id
  [/\bAKIA[0-9A-Z]{16}\b/g, "[REDACTED-AWS-AKID]"],
  // AWS secret access key (40 char base64-ish) — risky pattern, only in obvious context
  [
    /aws_secret_access_key\s*=\s*["']?[A-Za-z0-9/+=]{40}["']?/gi,
    "aws_secret_access_key=[REDACTED]",
  ],
  // GitHub PAT (classic + fine-grained)
  [/\bgh[pousr]_[A-Za-z0-9]{36,251}\b/g, "[REDACTED-GH-TOKEN]"],
  // Anthropic API key
  [/\bsk-ant-[A-Za-z0-9_-]{32,}\b/g, "[REDACTED-ANTHROPIC]"],
  // OpenAI API key
  [/\bsk-[A-Za-z0-9]{32,}\b/g, "[REDACTED-OPENAI]"],
  // Slack tokens
  [/\bxox[baprs]-[A-Za-z0-9-]{10,}\b/g, "[REDACTED-SLACK]"],
  // age secret key (bech32 alphabet — case insensitive)
  [/AGE-SECRET-KEY-[A-Za-z0-9]+/g, "[REDACTED-AGE]"],
];

function sanitize(s: string, redactSecrets: boolean, stats: Stats): string {
  if (!s) return s;
  let out = s;
  // strip <private>...</private>
  const before = out.length;
  out = out.replace(PRIVATE_BLOCK, "");
  if (out.length !== before) stats.privateBlocksStripped++;
  if (redactSecrets) {
    for (const [pat, replacement] of SECRET_PATTERNS) {
      const m = out.match(pat);
      if (m) {
        stats.redactionsApplied += m.length;
        out = out.replace(pat, replacement);
      }
    }
  }
  return out;
}

// ---- mapping -----------------------------------------------------------

/** parse ISO 8601 to ms; returns null if invalid */
function tsMs(iso?: string): number | null {
  if (!iso) return null;
  const n = Date.parse(iso);
  return Number.isFinite(n) ? n : null;
}

/** stringify a tool_result content array into a readable blob */
function stringifyToolResultContent(content: any): string {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return JSON.stringify(content);
  // each item likely {type:"text", text:"..."} or {type:"tool_reference", tool_name:"..."}
  return content
    .map((c) => {
      if (typeof c === "string") return c;
      if (c?.type === "text" && typeof c.text === "string") return c.text;
      if (c?.type === "tool_reference") return `<ref:${c.tool_name}>`;
      return JSON.stringify(c);
    })
    .join("\n");
}

/** extract observations from a single archive turn */
function turnToObservations(
  turn: ArchiveTurn,
  sessionId: string,
  ts: number,
): Array<
  Omit<
    ObservationRow,
    "type" | "session_id" | "ts" | "intensity" | "compressed"
  >
> {
  const out: Array<{
    kind: ObservationRow["kind"];
    content: string;
    metadata?: string;
  }> = [];

  if (turn.type === "user") {
    const c = turn.message?.content;
    if (typeof c === "string") {
      out.push({ kind: "user_prompt", content: c });
    } else if (Array.isArray(c)) {
      for (const block of c) {
        if (block?.type === "text" && typeof block.text === "string") {
          out.push({ kind: "user_prompt", content: block.text });
        } else if (block?.type === "tool_result") {
          const body = stringifyToolResultContent(block.content);
          const errFlag = block.is_error ? " is_error=true" : "";
          out.push({
            kind: "tool_result",
            content: `tool_use_id=${block.tool_use_id}${errFlag}\n${body}`,
            metadata: block.tool_use_id
              ? JSON.stringify({ tool_use_id: block.tool_use_id })
              : undefined,
          });
        }
        // ignore other block types (image, document, etc.)
      }
    }
  } else if (turn.type === "assistant") {
    const c = turn.message?.content;
    if (Array.isArray(c)) {
      for (const block of c) {
        if (block?.type === "text" && typeof block.text === "string") {
          out.push({ kind: "assistant", content: block.text });
        } else if (block?.type === "thinking") {
          const txt = block.thinking ?? block.text ?? "";
          if (typeof txt === "string" && txt.trim()) {
            out.push({ kind: "thinking", content: txt });
          }
        } else if (block?.type === "tool_use") {
          const name = block.name ?? "?";
          const input =
            block.input != null ? JSON.stringify(block.input) : "{}";
          out.push({
            kind: "tool_use",
            content: `${name} input=${input}`,
            metadata: JSON.stringify({ tool: name, tool_use_id: block.id }),
          });
        }
      }
    } else if (typeof c === "string") {
      out.push({ kind: "assistant", content: c });
    }
  }
  // other types (system, summary, operation, file-history-snapshot, sidechain markers) → no obs
  return out;
}

// ---- main --------------------------------------------------------------

async function main() {
  const args = parseArgs();
  const HOME = process.env.HOME!;
  const ARCHIVE =
    args.archive ?? path.join(HOME, ".config/superpowers/conversation-archive");

  // load privacy settings
  const settingsPath = path.join(HOME, ".cavemem/settings.json");
  let settings: Settings = {};
  try {
    settings = JSON.parse(fs.readFileSync(settingsPath, "utf8"));
  } catch (e) {
    console.warn(
      `warn: cannot read ${settingsPath}: ${e}; no exclusions, no redaction`,
    );
  }
  const excludePatterns = settings.privacy?.excludePatterns ?? [];
  const redactSecrets = !!settings.privacy?.redactSecrets;
  const excludes = compileExcludes(excludePatterns);
  console.error(
    `[seed] excludes=${excludePatterns.length} redactSecrets=${redactSecrets}`,
  );

  // determine output path. Two-pass: stream observations to a temp file
  // first, then prepend aggregated session rows when scan is complete.
  const outPath =
    args.out ??
    `/tmp/cavemem-seed-${new Date().toISOString().replace(/[:.]/g, "-")}.jsonl`;
  const obsTmpPath = args.dryRun ? null : `${outPath}.obs.tmp`;
  const writer = obsTmpPath ? fs.createWriteStream(obsTmpPath) : null;

  const stats: Stats = {
    filesScanned: 0,
    filesSkippedNoSession: 0,
    sessionsSkippedExcluded: 0,
    sessionsEmitted: 0,
    observationsEmitted: 0,
    observationsSkippedEmpty: 0,
    observationsSkippedUnknownType: 0,
    redactionsApplied: 0,
    privateBlocksStripped: 0,
    byKind: {},
  };

  // session aggregation: same sessionId can span multiple .jsonl files
  // (compaction splits). Track {minStart, maxEnd, cwd, ide} per sid; emit
  // one session row at the end.
  const sessionMap = new Map<
    string,
    { cwd: string; startedAt: number; endedAt: number }
  >();

  // iterate archive .jsonl
  const glob = new Glob("**/*.jsonl");
  let processed = 0;
  for await (const rel of glob.scan({ cwd: ARCHIVE, onlyFiles: true })) {
    if (args.limit && processed >= args.limit) break;
    processed++;
    stats.filesScanned++;
    const file = path.join(ARCHIVE, rel);

    let raw: string;
    try {
      raw = fs.readFileSync(file, "utf8");
    } catch (e) {
      console.error(`[skip] read fail ${file}: ${e}`);
      continue;
    }
    const lines = raw.split("\n").filter((l) => l.length > 0);
    if (lines.length === 0) {
      stats.filesSkippedNoSession++;
      continue;
    }

    // parse turns; tolerate bad lines
    const turns: ArchiveTurn[] = [];
    for (const line of lines) {
      try {
        turns.push(JSON.parse(line));
      } catch {
        // skip malformed line
      }
    }

    // find first turn with sessionId+timestamp
    const firstWithSid = turns.find((t) => t.sessionId);
    const sessionId = firstWithSid?.sessionId;
    if (!sessionId) {
      stats.filesSkippedNoSession++;
      continue;
    }

    // session cwd: prefer first turn with cwd; else derive from subdir name
    const firstWithCwd = turns.find((t) => t.cwd);
    let cwd = firstWithCwd?.cwd ?? "";
    if (!cwd) {
      // archive subdir encodes cwd: leading dir of `rel`, like `-Users-mrugesh-DEV-Pencil-Designs`
      const subdir = rel.split("/")[0] ?? "";
      cwd = subdir.startsWith("-") ? subdir.replace(/-/g, "/") : subdir;
    }

    if (isExcluded(cwd, excludes)) {
      stats.sessionsSkippedExcluded++;
      continue;
    }

    const tsList = turns
      .map((t) => tsMs(t.timestamp))
      .filter((n): n is number => n !== null);
    if (tsList.length === 0) {
      stats.filesSkippedNoSession++;
      continue;
    }
    const startedAt = tsList[0];
    const endedAt = tsList[tsList.length - 1];

    // accumulate session info (dedupe across files for same sid)
    const prev = sessionMap.get(sessionId);
    if (prev) {
      prev.startedAt = Math.min(prev.startedAt, startedAt);
      prev.endedAt = Math.max(prev.endedAt, endedAt);
      // keep first-seen cwd; rare drift across files for same sid
    } else {
      sessionMap.set(sessionId, { cwd, startedAt, endedAt });
    }

    // emit observations
    for (const turn of turns) {
      const ts = tsMs(turn.timestamp);
      if (ts === null) continue;
      const obs = turnToObservations(turn, sessionId, ts);
      if (
        obs.length === 0 &&
        (turn.type === "user" || turn.type === "assistant")
      ) {
        // tracked separately so we can spot mapping holes
        // (but legitimate empty: assistant turn with only stop_reason etc.)
      }
      for (const o of obs) {
        const sanitized = sanitize(o.content, redactSecrets, stats);
        if (!sanitized.trim()) {
          stats.observationsSkippedEmpty++;
          continue;
        }
        const row: ObservationRow = {
          type: "observation",
          session_id: sessionId,
          kind: o.kind,
          content: sanitized,
          ts,
          intensity: "full",
          compressed: 0,
          ...(o.metadata ? { metadata: o.metadata } : {}),
        };
        if (writer) writer.write(JSON.stringify(row) + "\n");
        stats.observationsEmitted++;
        stats.byKind[o.kind] = (stats.byKind[o.kind] ?? 0) + 1;
      }
    }
  }

  if (writer) {
    await new Promise<void>((res) => writer.end(() => res()));
  }

  // assemble final JSONL: sessions (deduped, aggregated) first, then obs from tmp
  if (!args.dryRun && obsTmpPath) {
    const final = fs.createWriteStream(outPath);
    for (const [sid, info] of sessionMap) {
      const row: SessionRow = {
        type: "session",
        id: sid,
        ide: "claude-code",
        cwd: info.cwd,
        started_at: info.startedAt,
        ended_at: info.endedAt,
      };
      final.write(JSON.stringify(row) + "\n");
      stats.sessionsEmitted++;
    }
    // append obs lines from tmp
    const obsBuf = fs.readFileSync(obsTmpPath, "utf8");
    if (obsBuf.length > 0) final.write(obsBuf);
    await new Promise<void>((res) => final.end(() => res()));
    fs.unlinkSync(obsTmpPath);
  } else if (args.dryRun) {
    // count distinct sessions for dry-run stats
    stats.sessionsEmitted = sessionMap.size;
  }

  console.error(`[seed] done`);
  console.error(JSON.stringify(stats, null, 2));
  console.error(
    args.dryRun ? "[seed] dry-run, no file written" : `[seed] wrote ${outPath}`,
  );

  if (args.import && !args.dryRun) {
    console.error("[seed] running cavemem import (writes to live db)…");
    const proc = Bun.spawn(["cavemem", "import", outPath], {
      stdio: ["inherit", "inherit", "inherit"],
    });
    const code = await proc.exited;
    if (code !== 0) {
      console.error(`[seed] cavemem import exited ${code}`);
      process.exit(code ?? 1);
    }
    console.error(
      "[seed] cavemem import done. Run `cavemem reindex` to refresh FTS.",
    );
  } else if (!args.dryRun) {
    console.error(
      `[seed] next: backup ~/.cavemem/data.db then run \`cavemem import ${outPath} && cavemem reindex\``,
    );
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
