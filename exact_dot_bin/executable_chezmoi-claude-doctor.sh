#!/usr/bin/env bash
# chezmoi-claude-doctor — detect drift in ~/.claude/ vs chezmoi sources.
# Exits 1 on any issue. No allowlist file: pure shape + coverage.
#
# Five checks:
#   1. chezmoi status   — managed files modified in place (drift in source-tracked content).
#   2. coverage         — files inside managed top-level dirs that aren't themselves managed
#                         (catches external installers dropping files into ~/.claude/hooks/, etc.).
#   3. shape filter     — unmanaged top-level config-shape files (*.md/.toml/.yaml/.yml/.kdl/.ini)
#                         (catches hand-edited orphan docs like the original RTK.md case).
#   4. mcp drift        — settings.json.mcpServers (canonical) vs ~/.claude.json (runtime),
#                         delegated to `chezmoi diff ~/.claude.json`.
#   5. lint             — schema-shape checks against ARCHI "Drift detection" gaps:
#                           5a. enabledPlugins values must be boolean (array form silently disables in CC 2.1.x).
#                           5b. mcpServers entries must declare `type` (stdio/http/sse).
#                           5c. log `claude --version` informationally (no pin — operator policy 2026-05-15).
#                           5d. SKILL.md frontmatter `name:` must match parent directory.
#
# Usage:
#   chezmoi-claude-doctor.sh           # report + non-zero exit on drift
#   chezmoi-claude-doctor.sh --quiet   # exit code only
#   chezmoi-claude-doctor.sh --test    # synthetic round-trip (creates+detects+cleans)
#   chezmoi-claude-doctor.sh --rewake  # hook mode: issue lines on stderr, exit 2 when any

set -uo pipefail

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
PUB_SOURCE="${PUB_SOURCE:-$HOME/.dotfiles}"
PRIV_SOURCE="${PRIV_SOURCE:-$HOME/.dotfiles}"
SHAPE_EXTS="${SHAPE_EXTS:-md|toml|yaml|yml|kdl|ini}"
# ARCHI_CC_VERSION_PIN removed 2026-05-15 — operator policy: no version pins.

QUIET=0
MODE="run"
case "${1:-}" in
--quiet) QUIET=1 ;;
--test) MODE="test" ;;
--rewake) MODE="rewake" ;;
--help | -h)
	sed -n '2,23p' "$0"
	exit 0
	;;
'') ;;
*)
	printf 'unknown arg: %s\n' "$1" >&2
	exit 2
	;;
esac

err() { printf '%s\n' "$*" >&2; }
log() { [[ "$QUIET" -eq 1 ]] || printf '%s\n' "$*"; }

require() {
	command -v "$1" >/dev/null 2>&1 || {
		err "missing dependency: $1"
		exit 2
	}
}

build_managed() {
	[[ -d "$PUB_SOURCE" ]] || return 0
	chezmoi managed --source "$PUB_SOURCE" --path-style absolute 2>/dev/null | sort -u
}

load_ignored() {
	# Only load patterns from priv source, scoped to .claude/ subtree.
	# Pub source's ignores are about what pub does NOT manage — irrelevant for
	# drift detection in ~/.claude/ (priv is the manager there).
	IGNORED_PATTERNS=()
	local f="$PRIV_SOURCE/.chezmoiignore"
	[[ -r "$f" ]] || return 0
	local line
	while IFS= read -r line; do
		line="${line%%#*}"
		line="${line#"${line%%[![:space:]]*}"}"
		line="${line%"${line##*[![:space:]]}"}"
		[[ -z "$line" || "$line" == "!"* ]] && continue
		[[ "$line" == .claude/* ]] || continue
		IGNORED_PATTERNS+=("$HOME/$line")
	done <"$f"
}

is_ignored() {
	local path="$1" pat prefix suffix
	for pat in "${IGNORED_PATTERNS[@]:-}"; do
		[[ -z "$pat" ]] && continue
		# exact match
		[[ "$path" == "$pat" ]] && return 0
		# pattern names a dir on disk: match anything under it
		if [[ -d "$pat" && "$path" == "$pat"/* ]]; then
			return 0
		fi
		# globstar: <prefix>/**/<suffix>
		if [[ "$pat" == *'/**/'* ]]; then
			prefix="${pat%%/\*\*/*}"
			suffix="${pat##*/\*\*/}"
			# shellcheck disable=SC2053
			[[ "$path" == "$prefix"/*"$suffix" || "$path" == "$prefix"/*/$suffix ]] && return 0
		fi
		# trailing /** : whole subtree
		if [[ "$pat" == *'/**' ]]; then
			[[ "$path" == "${pat%/**}"/* ]] && return 0
		fi
		# single-segment glob (no globstar)
		if [[ "$pat" == *'*'* && "$pat" != *'**'* ]]; then
			# shellcheck disable=SC2053
			[[ "$path" == $pat ]] && return 0
		fi
	done
	return 1
}

build_status() {
	[[ -d "$PUB_SOURCE" ]] || return 0
	chezmoi status --source "$PUB_SOURCE" 2>/dev/null | grep -F "$CLAUDE_DIR" 2>/dev/null | sort -u
}

# Extract top-level paths under $CLAUDE_DIR: <CLAUDE_DIR>/<first-segment>
top_level_managed() {
	sed -nE "s|^(${CLAUDE_DIR}/[^/]+).*|\\1|p" "$MANAGED_FILE" | sort -u
}

is_managed_path() {
	grep -qxF "$1" "$MANAGED_FILE"
}

check_status() {
	local out lines
	out="$(build_status)"
	if [[ -n "$out" ]]; then
		log "$out"
		lines=$(printf '%s\n' "$out" | wc -l | tr -d ' ')
		return "$lines"
	fi
	log '  clean'
	return 0
}

check_coverage() {
	local mdir f found=0
	while IFS= read -r mdir; do
		[[ -d "$mdir" ]] || continue
		[[ -L "$mdir" ]] && continue
		while IFS= read -r f; do
			is_managed_path "$f" && continue
			is_ignored "$f" && continue
			log "  ORPHAN: $f"
			found=$((found + 1))
		done < <(find "$mdir" -type f 2>/dev/null)
	done < <(top_level_managed)
	[[ "$found" -eq 0 ]] && log '  clean'
	return "$found"
}

check_shape() {
	local f found=0
	while IFS= read -r f; do
		is_managed_path "$f" && continue
		is_ignored "$f" && continue
		log "  ORPHAN: $f"
		found=$((found + 1))
	done < <(find -E "$CLAUDE_DIR" -mindepth 1 -maxdepth 1 -type f -regex ".*\\.(${SHAPE_EXTS})$" 2>/dev/null)
	[[ "$found" -eq 0 ]] && log '  clean'
	return "$found"
}

check_mcp() {
	local out
	if ! command -v chezmoi >/dev/null 2>&1; then
		log '  skip (chezmoi missing)'
		return 0
	fi
	out=$(chezmoi diff "$HOME/.claude.json" 2>/dev/null) || true
	if [[ -z "$out" ]]; then
		log '  clean'
		return 0
	fi
	log '  DRIFT between dot_claude/settings.json and ~/.claude.json'
	printf '%s\n' "$out" | sed 's/^/  /' | while IFS= read -r line; do log "$line"; done
	return 1
}

# Lint stage: schema-shape checks against ARCHI "Drift detection" gaps. Each sub-check
check_lint() {
	local settings="$PRIV_SOURCE/dot_claude/settings.json"
	local found=0

	# 5a + 5b: settings.json shape (need jq + source present)
	if command -v jq >/dev/null 2>&1 && [[ -r "$settings" ]]; then
		local bad
		bad=$(jq -r '(.enabledPlugins // {}) | to_entries[] | select(.value | type != "boolean") | .key' "$settings" 2>/dev/null)
		if [[ -n "$bad" ]]; then
			while IFS= read -r p; do
				[[ -z "$p" ]] && continue
				log "  LINT: enabledPlugins[$p] is not boolean (CC 2.1.x silently disables array form)"
				found=$((found + 1))
			done <<<"$bad"
		fi

		local missing_type
		missing_type=$(jq -r '(.mcpServers // {}) | to_entries[] | select(.value | type == "object" and (has("type") | not)) | .key' "$settings" 2>/dev/null)
		if [[ -n "$missing_type" ]]; then
			while IFS= read -r p; do
				[[ -z "$p" ]] && continue
				log "  LINT: mcpServers[$p] missing 'type' field (stdio/http/sse)"
				found=$((found + 1))
			done <<<"$missing_type"
		fi
	fi

	# 5c: Claude Code version — informational only (no pin enforced).
	# Operator policy: never pin versions; track upstream "latest". Surface
	# the current version so the operator can spot major bumps in passing.
	if command -v claude >/dev/null 2>&1; then
		local cur
		cur=$(claude --version 2>/dev/null | awk '{print $1}')
		[[ -n "$cur" ]] && log "  INFO: claude --version=$cur (informational)"
	fi

	# 5d: skill name:dir frontmatter mismatch
	local skill_root="$PRIV_SOURCE/dot_claude/skills"
	if [[ -d "$skill_root" ]]; then
		local sd skill_md fm_name dir_name
		while IFS= read -r sd; do
			skill_md="$sd/SKILL.md"
			[[ -r "$skill_md" ]] || continue
			fm_name=$(awk '
				/^---[[:space:]]*$/ { fm = !fm; next }
				fm && /^name:/      { sub(/^name:[[:space:]]*/, ""); gsub(/["'"'"']/, ""); print; exit }
			' "$skill_md")
			dir_name=$(basename "$sd")
			if [[ -n "$fm_name" && "$fm_name" != "$dir_name" ]]; then
				log "  LINT: skill frontmatter name='$fm_name' != dir='$dir_name' ($skill_md)"
				found=$((found + 1))
			fi
		done < <(find "$skill_root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
	fi

	[[ "$found" -eq 0 ]] && log '  clean'
	return "$found"
}

check_drift() {
	local pairs=(
		"$PRIV_SOURCE/dot_claude/settings.json:$CLAUDE_DIR/settings.json"
		"$PRIV_SOURCE/dot_claude/hooks/executable_hooks.py:$CLAUDE_DIR/hooks/hooks.py"
		"$PRIV_SOURCE/dot_claude/hooks/hook_config.json:$CLAUDE_DIR/hooks/hook_config.json"
	)
	local pair src tgt src_sha tgt_sha found=0
	for pair in "${pairs[@]}"; do
		src="${pair%%:*}"
		tgt="${pair#*:}"
		if [[ ! -r "$src" || ! -r "$tgt" ]]; then
			log "  WARN: $tgt or $src unreadable — drift: run chezmoi apply"
			found=$((found + 1))
			continue
		fi
		src_sha=$(shasum -a 256 "$src" | awk '{print $1}')
		tgt_sha=$(shasum -a 256 "$tgt" | awk '{print $1}')
		if [[ "$src_sha" != "$tgt_sha" ]]; then
			log "  WARN: $tgt drift: run chezmoi apply"
			found=$((found + 1))
		fi
	done
	[[ "$found" -eq 0 ]] && log '  clean'
	return "$found"
}

check_plugin_src_drift() {
	local installed="$CLAUDE_DIR/plugins/installed_plugins.json"
	if ! command -v jq >/dev/null 2>&1 || [[ ! -r "$installed" ]]; then
		log '  skip (jq or installed_plugins.json missing)'
		return 0
	fi
	local keys found=0
	keys=$(jq -r '.plugins | keys[]' "$installed" 2>/dev/null)
	if [[ -z "$keys" ]]; then
		log '  clean'
		return 0
	fi
	local key installed_sha own_src src_head
	own_src="${OWN_PLUGIN_SRC:-$HOME/DEV/rd/claude-code-plugins}"
	while IFS= read -r key; do
		[[ -z "$key" ]] && continue
		installed_sha=$(jq -r --arg k "$key" '.plugins[$k][0].gitCommitSha // empty' "$installed" 2>/dev/null)
		if [[ "$key" == *@raisedadead-plugins && -d "$own_src/.git" ]]; then
			src_head=$(git -C "$own_src" rev-parse HEAD 2>/dev/null)
			if [[ -n "$src_head" && -n "$installed_sha" && "$src_head" != "$installed_sha" ]]; then
				log "  WARN: $key installed sha != source HEAD (installed=${installed_sha:0:12} source=${src_head:0:12}) — push + /cmd-refresh-plugins to reconcile"
				found=$((found + 1))
			fi
		fi
	done <<<"$keys"
	[[ "$found" -eq 0 ]] && log '  clean'
	return "$found"
}

check_cavemem_abi() {
	local bin="$HOME/.local/share/fnm/aliases/default/bin/cavemem"
	if [[ ! -x "$bin" ]]; then
		log '  skip (cavemem binary missing)'
		return 0
	fi
	local xenova="$HOME/.local/share/fnm/aliases/default/lib/node_modules/@xenova/transformers"
	if [[ ! -d "$xenova" ]]; then
		log '  WARN: @xenova/transformers missing (undeclared cavemem dep) - semantic embeddings will not build; run chezmoi-claude-bootstrap.sh --only cavemem'
		return 1
	fi
	local node_bin="$HOME/.local/share/fnm/aliases/default/bin/node"
	local out rc=0
	out=$(printf '%s' '{"session_id":"doctor","tool_name":"Read","cwd":"/tmp"}' |
		timeout 5 "$node_bin" "$bin" hook run post-tool-use --ide claude-code 2>&1) || rc=$?
	if [[ "$rc" -ne 0 || "$out" != *'"ok":true'* ]]; then
		log '  WARN: cavemem hook failing - node ABI drift? run cavemem-repair workflow or rebuild better-sqlite3'
		return 1
	fi
	log '  clean'
	return 0
}

check_safeguard_toggle() {
	if ! command -v jq >/dev/null 2>&1; then
		log '  skip (jq missing)'
		return 0
	fi
	local rc=0 f v
	for f in "$PRIV_SOURCE/dot_claude/settings.json" "$CLAUDE_DIR/settings.json"; do
		if [[ ! -f "$f" ]]; then
			log "  skip (${f/#$HOME/~} missing)"
			continue
		fi
		v=$(jq -r '.switchModelsOnFlag' "$f" 2>/dev/null)
		if [[ "$v" != "false" ]]; then
			log "  WARN: switchModelsOnFlag != false in ${f/#$HOME/~} (got: $v) — safeguard flag will silently switch model; re-flip via /config"
			rc=1
		fi
	done
	if [[ -x "$HOME/.bin/claude-flag-audit.sh" ]]; then
		local n
		n=$("$HOME/.bin/claude-flag-audit.sh" 7 2>/dev/null | sed -n 's/^total .* last 7d //p')
		[[ -n "$n" && "$n" != "0" ]] && log "  note: $n safeguard flag(s) in last 7 days — claude-flag-audit.sh 7"
	fi
	[[ "$rc" -eq 0 ]] && log '  clean'
	return "$rc"
}

check_user_agents() {
	local agents_dir="$PRIV_SOURCE/dot_claude/agents"
	if [[ ! -d "$agents_dir" ]]; then
		log '  clean (no user agents)'
		return 0
	fi
	if ! command -v python3 >/dev/null 2>&1; then
		log '  skip (python3 missing)'
		return 0
	fi
	local out found
	out=$(
		python3 - "$agents_dir" "$CLAUDE_DIR/markers/subagent-spawns.jsonl" 4 <<'PYEOF'
import calendar, json, os, sys, time

agents_dir, log_path, cap = sys.argv[1], sys.argv[2], int(sys.argv[3])
names = sorted(f[:-3] for f in os.listdir(agents_dir) if f.endswith(".md"))
window, now = 30 * 86400, time.time()
issues = []

if len(names) > cap:
    issues.append("%d user agents exceed the cap of %d - see ARCHI 'Instructions & agents'" % (len(names), cap))

spawns = {}
try:
    with open(log_path) as fh:
        for line in fh:
            try:
                entry = json.loads(line)
                ts = calendar.timegm(time.strptime(entry.get("ts", ""), "%Y-%m-%dT%H:%M:%SZ"))
            except (ValueError, TypeError):
                continue
            if now - ts <= window:
                key = entry.get("agent_type", "")
                spawns[key] = spawns.get(key, 0) + 1
except OSError:
    pass

for name in names:
    if now - os.path.getmtime(os.path.join(agents_dir, name + ".md")) < window:
        continue
    if not spawns.get(name):
        issues.append("agent '%s' has 0 spawns in 30d - retire it or fix its trigger" % name)

print("\n".join(issues))
PYEOF
	)
	if [[ -n "$out" ]]; then
		found=0
		while IFS= read -r line; do
			[[ -z "$line" ]] && continue
			log "  WARN: $line"
			found=$((found + 1))
		done <<<"$out"
		return "$found"
	fi
	log '  clean'
	return 0
}

check_submodule() {
	local st
	st="$(git -C "$PRIV_SOURCE" submodule status dot_claude 2>/dev/null)"
	case "$st" in
	"-"* | "")
		err "dot_claude submodule not initialised: git -C $PRIV_SOURCE submodule update --init"
		exit 2
		;;
	"+"*) log "WARN: dot_claude checkout differs from the recorded gitlink; commit the bump in $PRIV_SOURCE" ;;
	esac
	[[ -f "$PRIV_SOURCE/dot_claude/settings.json" ]] || {
		err "missing $PRIV_SOURCE/dot_claude/settings.json"
		exit 2
	}
}

run_checks() {
	local rc1 rc2 rc3 rc4 rc5

	check_submodule

	log '[1/5] chezmoi status (managed-file modifications)'
	check_status
	rc1=$?
	log ''

	log '[2/5] coverage (unmanaged files inside managed dirs)'
	check_coverage
	rc2=$?
	log ''

	log "[3/5] shape (unmanaged top-level *.{${SHAPE_EXTS}})"
	check_shape
	rc3=$?
	log ''

	log '[4/5] mcp drift (settings.json vs ~/.claude.json user-level)'
	check_mcp
	rc4=$?
	log ''

	log '[5/5] lint (enabledPlugins/mcpServers shape, CC version, skill name)'
	check_lint
	rc5=$?
	log ''

	local total=$((rc1 + rc2 + rc3 + rc4 + rc5))
	log "Total issues: $total"

	log '[warn 1/5] drift (source vs rendered sha256: settings.json, hooks.py, hook_config.json)'
	check_drift
	log ''

	log '[warn 2/5] first-party plugin drift (installed sha vs claude-code-plugins source HEAD)'
	check_plugin_src_drift
	log ''

	log '[warn 3/5] cavemem ABI probe + embedder (@xenova) presence'
	check_cavemem_abi
	log ''

	log '[warn 4/5] safeguard toggle (switchModelsOnFlag=false in source + live settings.json)'
	check_safeguard_toggle
	log ''

	log '[warn 5/5] user agents (cap of 4, 0-spawn-in-30d staleness via subagent-spawns.jsonl)'
	check_user_agents
	log ''

	[[ "$total" -eq 0 ]]
}

self_test() {
	local mk_md="$CLAUDE_DIR/.doctor-test.md"
	local mk_in_dir="$CLAUDE_DIR/hooks/.doctor-test-orphan.tmp"

	log '[test] phase 1: clean baseline'
	if ! "$0" --quiet >/dev/null 2>&1; then
		err '[test] FAIL: pre-existing drift; full report:'
		"$0" >&2 || true
		return 1
	fi

	log '[test] phase 2: synthesize top-level *.md orphan'
	: >"$mk_md"
	build_managed >"$MANAGED_FILE" # rebuild (managed list unchanged but be safe)
	if "$0" --quiet >/dev/null 2>&1; then
		rm -f "$mk_md"
		err '[test] FAIL: shape check missed top-level *.md orphan'
		return 1
	fi
	rm -f "$mk_md"

	log '[test] phase 3: synthesize file inside managed dir (~/.claude/hooks/)'
	: >"$mk_in_dir"
	if "$0" --quiet >/dev/null 2>&1; then
		rm -f "$mk_in_dir"
		err '[test] FAIL: coverage check missed orphan in managed dir'
		return 1
	fi
	rm -f "$mk_in_dir"

	log '[test] phase 4: clean state restored'
	if ! "$0" --quiet >/dev/null 2>&1; then
		err '[test] FAIL: doctor still reports drift after cleanup'
		return 1
	fi

	log '[test] PASS'
	return 0
}

require chezmoi
require find
require sed
require grep
require sort

MANAGED_FILE=$(mktemp -t chezmoi-claude-doctor.XXXXXX) || exit 2
trap 'rm -f "$MANAGED_FILE"' EXIT

build_managed >"$MANAGED_FILE"
load_ignored

if [[ "$MODE" == "test" ]]; then
	self_test
	exit $?
fi

if [[ "$MODE" == "rewake" ]]; then
	report=$(run_checks 2>&1)
	rc=$?
	issues=$(grep -E 'WARN:|ORPHAN:|LINT:' <<<"$report")
	[[ "$rc" -eq 0 && -z "$issues" ]] && exit 0
	body=$issues
	[[ "$rc" -ne 0 ]] && body=$report
	{
		printf 'chezmoi-claude-doctor: issues found. Run ~/.bin/chezmoi-claude-doctor.sh for the full report.\n'
		printf '%s\n' "$body"
		[[ "$rc" -eq 0 ]] && grep -E '^Total issues' <<<"$report"
	} >&2
	exit 2
fi

run_checks
exit $?
