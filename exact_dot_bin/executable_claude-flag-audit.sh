#!/usr/bin/env bash
set -euo pipefail

VERBOSE=0
DAYS=""
for a in "$@"; do
	case "$a" in
	-h | --help)
		echo "Usage: claude-flag-audit.sh [days] [-v|--verbose]"
		echo "Lists Fable safeguard model_refusal_fallback events across all Claude transcripts."
		echo "  -v  also print requestId + apiRefusalExplanation per event (cite to Anthropic support)"
		exit 0
		;;
	-v | --verbose) VERBOSE=1 ;;
	*) DAYS="$a" ;;
	esac
done

python3 - "$DAYS" "$VERBOSE" <<'EOF'
import glob
import json
import os
import subprocess
import sys
from collections import Counter
from datetime import datetime, timedelta, timezone

days = sys.argv[1] if len(sys.argv) > 1 else ""
verbose = len(sys.argv) > 2 and sys.argv[2] == "1"
cutoff = None
if days:
    cutoff = (datetime.now(timezone.utc) - timedelta(days=int(days))).isoformat()

root = os.path.expanduser("~/.claude/projects")
paths = glob.glob(f"{root}/**/*.jsonl", recursive=True)
try:
    out = subprocess.run(
        ["grep", "-lF", '"model_refusal_fallback"', *paths],
        capture_output=True, text=True
    ).stdout.split()
except OSError:
    out = [p for p in paths if '"model_refusal_fallback"' in open(p, errors="ignore").read()]

events = []
for p in out:
    flags, users = [], {}
    for line in open(p, errors="ignore"):
        if '"model_refusal_fallback"' not in line and '"type":"user"' not in line:
            continue
        try:
            d = json.loads(line)
        except json.JSONDecodeError:
            continue
        if d.get("subtype") == "model_refusal_fallback":
            flags.append(d)
        elif d.get("type") == "user":
            users[d.get("uuid")] = d
    for d in flags:
        ts = d.get("timestamp", "")
        if cutoff and ts < cutoff:
            continue
        msg = users.get(d.get("refusedUserMessageUuid"))
        preview = ""
        if msg:
            c = msg.get("message", {}).get("content")
            if isinstance(c, str):
                preview = c
            elif isinstance(c, list):
                preview = " ".join(
                    b.get("text", "") for b in c
                    if isinstance(b, dict) and b.get("type") == "text"
                )
        preview = " ".join(preview.split())[:70]
        events.append({
            "ts": ts,
            "cwd": os.path.basename(d.get("cwd", "") or "?"),
            "cat": d.get("apiRefusalCategory") or "?",
            "from": (d.get("originalModel") or "?").replace("claude-", ""),
            "to": (d.get("fallbackModel") or "?").replace("claude-", ""),
            "session": (d.get("sessionId") or "?")[:8],
            "req": d.get("requestId") or "?",
            "exp": d.get("apiRefusalExplanation") or "",
            "msg": preview or "(unresolved)",
        })

events.sort(key=lambda e: e["ts"])
if not events:
    print("no safeguard flags found" + (f" in last {days}d" if days else ""))
    sys.exit(0)

for e in events:
    print(f"{e['ts'][:16]}  {e['cwd']:<22} {e['cat']:<8} {e['from']}→{e['to']}  "
          f"[{e['session']}]  {e['msg']}")
    if verbose:
        line = f"    req_id: {e['req']}"
        if e['exp']:
            line += f"  |  explanation: {e['exp']}"
        print(line)

week_ago = (datetime.now(timezone.utc) - timedelta(days=7)).isoformat()
by_cat = Counter(e["cat"] for e in events)
by_cwd = Counter(e["cwd"] for e in events)
print(f"\ntotal {len(events)} | last 7d {sum(1 for e in events if e['ts'] >= week_ago)}")
print("by category:", ", ".join(f"{k}={v}" for k, v in by_cat.most_common()))
print("by repo:", ", ".join(f"{k}={v}" for k, v in by_cwd.most_common()))
print("\nrecovery: new session (never /model fable in flagged session — re-flags)")
print("feedback: /feedback | toggle: /config → switch models when flagged → OFF")
EOF
