#!/usr/bin/env bash
# chezmoi-claude-doctor — detect drift in ~/.claude/ vs chezmoi sources.
# Exits 1 on any issue. No allowlist file: pure shape + coverage.
#
# Five checks:
#   1. chezmoi status   — managed files modified in place (drift in source-tracked content).
#   2. coverage         — files inside managed top-level dirs that aren't themselves managed
#                         (catches external installers dropping files into ~/.claude/agents/, etc.).
#   3. shape filter     — unmanaged top-level config-shape files (*.md/.toml/.yaml/.yml/.kdl/.ini)
#                         (catches hand-edited orphan docs like the original RTK.md case).
#   4. mcp drift        — settings.json.mcpServers (canonical) vs ~/.claude.json (runtime),
#                         compared with jq on .mcpServers, plus a 0600 mode check.
#   5. lint             — schema-shape checks:
#                           5a. enabledPlugins values must be boolean (array form silently disables in CC 2.1.x).
#                           5b. mcpServers entries must declare `type` (stdio/http/sse).
#                           5c. log `claude --version` informationally (no pin — operator policy 2026-05-15).
#                           5d. SKILL.md frontmatter `name:` must match parent directory.
#                           5e. skill layers: ~/.claude/skills links resolve into ../../.agents/skills/<name>,
#                               symlink_<name> source entries match a dot_agents/skills/<name>, and no
#                               common skill is also a CLI-installed copy (skills lock).
#
# Usage:
#   chezmoi-claude-doctor.sh           # report + non-zero exit on drift
#   chezmoi-claude-doctor.sh --quiet   # exit code only
#   chezmoi-claude-doctor.sh --test    # synthetic round-trip (creates+detects+cleans)
#   chezmoi-claude-doctor.sh --rewake  # hook mode: issues on stderr with exit 2; WARN lines to ~/.claude/markers/doctor-warnings.txt

set -uo pipefail

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
PUB_SOURCE="${PUB_SOURCE:-$HOME/.dotfiles}"
PRIV_SOURCE="${PRIV_SOURCE:-$HOME/.dotfiles}"
SHAPE_EXTS="${SHAPE_EXTS:-md|toml|yaml|yml|kdl|ini}"
CAVEMEM_HEALTH="${CAVEMEM_HEALTH:-$HOME/.bin/cavemem-health.sh}"
CODEX_RELEASES="${CODEX_RELEASES:-$HOME/.codex/packages/app-server-daemon/releases}"
PI_RELEASES="${PI_RELEASES:-$HOME/.pi/agent/install/releases}"
ADDITIONS_FILE="${ADDITIONS_FILE:-$PUB_SOURCE/docs/agent-additions.txt}"
# ARCHI_CC_VERSION_PIN removed 2026-05-15 — operator policy: no version pins.

SELF=$(command -v -- "$0" 2>/dev/null) || SELF="$0"
[[ "$SELF" == /* ]] || SELF="$PWD/$SELF"

QUIET=0
MODE="run"
case "${1:-}" in
--quiet) QUIET=1 ;;
--test) MODE="test" ;;
--rewake) MODE="rewake" ;;
--help | -h)
	sed -n '2,26p' "$SELF"
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
		exit "$FAIL_RC"
	}
}

git_common_dir() {
	git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null
}

rewake_applies() {
	local here root src
	[[ -n "$1" ]] || return 1
	here=$(git_common_dir "$1")
	[[ -n "$here" ]] || return 1
	for src in "$PUB_SOURCE" "$PRIV_SOURCE"; do
		root=$(git_common_dir "$src")
		[[ -n "$root" ]] || continue
		[[ "$here" == "$root" || "$here" == "$root"/* ]] && return 0
	done
	return 1
}

session_cwd() {
	local payload="" cwd=""
	if [[ ! -t 0 ]]; then
		IFS= read -r -d '' -t 1 payload || true
	fi
	if [[ -n "$payload" ]] && command -v jq >/dev/null 2>&1; then
		cwd=$(jq -r '.cwd // empty' <<<"$payload" 2>/dev/null)
	fi
	printf '%s' "${cwd:-$PWD}"
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
	chezmoi status --source "$PUB_SOURCE" --path-style absolute -- "$CLAUDE_DIR" | sort -u
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
	if ! out="$(build_status 2>/dev/null)"; then
		log '  ERROR: chezmoi status failed'
		return 1
	fi
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
	local settings="$PRIV_SOURCE/dot_claude/.settings.managed.json"
	local runtime="$HOME/.claude.json"
	local canonical live mode out found=0
	if ! command -v jq >/dev/null 2>&1; then
		log '  skip (jq missing)'
		return 0
	fi
	if [[ ! -r "$settings" ]]; then
		log '  skip (dot_claude/.settings.managed.json unreadable)'
		return 0
	fi
	if [[ ! -r "$runtime" ]]; then
		log '  DRIFT: ~/.claude.json is absent or unreadable'
		return 1
	fi
	if ! jq empty "$settings" 2>/dev/null; then
		log '  LINT: dot_claude/.settings.managed.json is not valid JSON'
		return 1
	fi
	mode=$(stat -f '%Lp' "$runtime" 2>/dev/null)
	if [[ "$mode" != 600 ]]; then
		log "  DRIFT: ~/.claude.json mode is ${mode:-unknown}, not 600"
		found=$((found + 1))
	fi
	if ! canonical=$(jq -Se '.mcpServers' "$settings" 2>/dev/null); then
		log '  skip (settings.json declares no mcpServers; apply is a passthrough)'
		return "$found"
	fi
	if ! live=$(jq -S '.mcpServers // {}' "$runtime" 2>/dev/null); then
		log '  LINT: ~/.claude.json is not valid JSON'
		return $((found + 1))
	fi
	if [[ "$canonical" == "$live" ]]; then
		[[ "$found" -eq 0 ]] && log '  clean'
		return "$found"
	fi
	log '  DRIFT in mcpServers (dot_claude/.settings.managed.json is canonical)'
	out=$(diff -u --label '.claude.json' --label 'settings.json' \
		<(printf '%s\n' "$live") <(printf '%s\n' "$canonical"))
	printf '%s\n' "$out" | sed 's/^/  /' | while IFS= read -r line; do log "$line"; done
	return $((found + 1))
}

# Lint stage: schema-shape checks. Each sub-check
check_lint() {
	local settings="$PRIV_SOURCE/dot_claude/.settings.managed.json"
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
	local skill_root sd skill_md fm_name dir_name
	for skill_root in "$PRIV_SOURCE/dot_claude/skills" "$PRIV_SOURCE/dot_agents/skills"; do
		[[ -d "$skill_root" ]] || continue
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
	done

	# 5e: skill layers
	local link target name entry
	local common_root="$PRIV_SOURCE/dot_agents/skills"
	local lock="$HOME/.agents/.skill-lock.json"
	[[ -n "${XDG_STATE_HOME:-}" ]] && lock="$XDG_STATE_HOME/skills/.skill-lock.json"
	while IFS= read -r link; do
		name=$(basename "$link")
		target=$(readlink "$link")
		if [[ ! -e "$link" ]]; then
			log "  LINT: skill link $link is dangling"
			found=$((found + 1))
		elif [[ "$target" != "../../.agents/skills/$name" ]]; then
			log "  LINT: skill link $link targets '$target', not '../../.agents/skills/$name'"
			found=$((found + 1))
		fi
	done < <(find "$CLAUDE_DIR/skills" -mindepth 1 -maxdepth 1 -type l 2>/dev/null)
	while IFS= read -r entry; do
		name=$(basename "$entry")
		name="${name#symlink_}"
		target=$(<"$entry")
		if [[ "$target" != "../../.agents/skills/$name" ]]; then
			log "  LINT: $entry holds '$target', not '../../.agents/skills/$name'"
			found=$((found + 1))
		fi
		if [[ ! -r "$common_root/$name/SKILL.md" ]]; then
			log "  LINT: $entry has no $common_root/$name/SKILL.md"
			found=$((found + 1))
		fi
	done < <(find "$PRIV_SOURCE/dot_claude/skills" -mindepth 1 -maxdepth 1 -type f -name 'symlink_*' 2>/dev/null)
	if [[ -d "$common_root" && -r "$lock" ]] && command -v jq >/dev/null 2>&1; then
		while IFS= read -r sd; do
			name=$(basename "$sd")
			if jq -e --arg n "$name" '.skills | has($n)' "$lock" >/dev/null 2>&1; then
				log "  LINT: common skill '$name' is also a CLI-installed copy ($lock)"
				found=$((found + 1))
			fi
		done < <(find "$common_root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
	fi

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
	local key name rc installed_sha own_src main_sha
	own_src="${OWN_PLUGIN_SRC:-$HOME/DEV/rd/claude-code-plugins}"
	if [[ -d "$own_src/.git" ]] && ! main_sha=$(git -C "$own_src" rev-parse --verify -q 'origin/main^{commit}' 2>/dev/null); then
		log "  note: $own_src has no origin/main — fetch it to compare the installs"
		return 0
	fi
	while IFS= read -r key; do
		[[ "$key" == *@raisedadead-plugins && -d "$own_src/.git" ]] || continue
		installed_sha=$(jq -r --arg k "$key" '.plugins[$k][0].gitCommitSha // empty' "$installed" 2>/dev/null)
		[[ -n "$installed_sha" ]] || continue
		if ! git -C "$own_src" cat-file -e "$installed_sha^{commit}" 2>/dev/null; then
			log "  note: $key installed ${installed_sha:0:12} is not in $own_src — fetch to compare it with origin/main"
			continue
		fi
		git -C "$own_src" merge-base --is-ancestor "$main_sha" "$installed_sha" 2>/dev/null && continue
		name="${key%@*}"
		rc=0
		git -C "$own_src" diff --quiet "$installed_sha" "$main_sha" -- "plugins/$name" ":(exclude)plugins/$name/CHANGELOG.md" || rc=$?
		[[ "$rc" -eq 0 ]] && continue
		if [[ "$rc" -ne 1 ]]; then
			log "  note: $key git diff exited $rc in $own_src"
			continue
		fi
		log "  WARN: $key installed ${installed_sha:0:12} differs from plugins/$name on origin/main (${main_sha:0:12}) — run /cmd-refresh-plugins"
		found=$((found + 1))
	done <<<"$keys"
	[[ "$found" -eq 0 ]] && log '  clean'
	return "$found"
}

check_cavemem_abi() {
	local out msg
	if [[ ! -x "$CAVEMEM_HEALTH" ]]; then
		log "  WARN: $CAVEMEM_HEALTH missing - run chezmoi apply ~/.bin"
		return 1
	fi
	if out=$("$CAVEMEM_HEALTH"); then
		log '  clean'
		return 0
	fi
	if [[ "$out" == missing\ * ]]; then
		log '  skip (cavemem binary missing)'
		return 0
	fi
	while read -r _ msg; do
		log "  WARN: $msg - run chezmoi-claude-bootstrap.sh --only cavemem"
	done <<<"$out"
	return 1
}

check_safeguard_toggle() {
	if ! command -v jq >/dev/null 2>&1; then
		log '  skip (jq missing)'
		return 0
	fi
	local rc=0 f v
	for f in "$PRIV_SOURCE/dot_claude/.settings.managed.json" "$CLAUDE_DIR/settings.json"; do
		if [[ ! -f "$f" ]]; then
			log "  skip (${f/#$HOME/\~} missing)"
			continue
		fi
		v=$(jq -r '.switchModelsOnFlag' "$f" 2>/dev/null)
		if [[ "$v" != "false" ]]; then
			log "  WARN: switchModelsOnFlag != false in ${f/#$HOME/\~} (got: $v) — safeguard flag will silently switch model; re-flip via /config"
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

rig_gate_run() {
	local out=$1 work rc
	work=$(mktemp -d) || return 1
	{
		git -C "$PRIV_SOURCE/dot_claude" archive HEAD mods/rig | tar -x -C "$work" &&
			(cd "$work/mods/rig" && bun build.ts && claude plugin validate dist && claude plugin test dist)
	} >"$out" 2>&1
	rc=$?
	rm -rf "$work"
	return "$rc"
}

check_rig_gate() {
	local types="$CLAUDE_DIR/mods/rig/.claude-plugin/types/claude-code/index.d.ts"
	local marker="$CLAUDE_DIR/markers/rig-verified-version"
	local out="$CLAUDE_DIR/markers/rig-gate.log"
	local version passed bin
	if [[ ! -f "$types" ]]; then
		log '  skip (no host types; Claude Code writes them when it loads the rig)'
		return 0
	fi
	version=$(sed -nE '1s#^// Written by Claude Code ([^ ]+)\.$#\1#p' "$types")
	if [[ -z "$version" ]]; then
		log "  WARN: line 1 of ${types/#$HOME/\~} names no Claude Code version"
		return 1
	fi
	passed=$(cat "$marker" 2>/dev/null)
	if [[ "$version" == "$passed" ]]; then
		log "  clean ($version verified)"
		return 0
	fi
	for bin in claude bun bunx git; do
		if ! command -v "$bin" >/dev/null 2>&1; then
			log "  skip ($bin missing)"
			return 0
		fi
	done
	if [[ ! -d "$PRIV_SOURCE/dot_claude/mods/rig" ]]; then
		log "  skip (${PRIV_SOURCE/#$HOME/\~}/dot_claude/mods/rig missing)"
		return 0
	fi
	mkdir -p "${marker%/*}"
	if ! rig_gate_run "$out"; then
		log "  WARN: the committed rig fails build, validate or tests on Claude Code $version; read ${out/#$HOME/\~}"
		return 1
	fi
	printf '%s\n' "$version" >"$marker"
	log "  clean ($version verified now)"
}

check_ai_releases() {
	local rc=0 dir n size
	for dir in "$CODEX_RELEASES" "$PI_RELEASES"; do
		if [[ ! -d "$dir" ]]; then
			log "  skip (${dir/#$HOME/\~} missing)"
			continue
		fi
		n=$(find "$dir" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
		if ((n > 2)); then
			size=$(du -sh "$dir" | awk '{print $1}')
			log "  WARN: ${dir/#$HOME/\~} holds $n releases ($size); keep only the newest two"
			rc=1
		fi
	done
	[[ "$rc" -eq 0 ]] && log '  clean'
	return "$rc"
}

check_links() {
	local rc=0 link
	while IFS= read -r link; do
		[[ -e "$link" ]] && continue
		log "  WARN: ${link/#$HOME/\~} points to a missing $(readlink "$link"); reinstall the target or run its setup command"
		rc=1
	done < <(find "$HOME/.bin" "$CLAUDE_DIR/skills" -mindepth 1 -maxdepth 1 -type l 2>/dev/null)
	[[ "$rc" -eq 0 ]] && log '  clean'
	return "$rc"
}

jq_items() {
	local file=$1
	shift
	[[ -e "$file" ]] || return 0
	jq -r "$@" "$file" 2>/dev/null || printf 'unreadable %s\n' "${file#"$HOME"/}"
}

list_unmanaged_children() {
	local kind=$1 dir=$2 manifest=${3:-} path name file
	[[ -d "$dir" ]] || return 0
	while IFS= read -r path; do
		name=${path##*/}
		is_ignored "$path" && continue
		if is_managed_path "$path"; then
			[[ -d "$path" && ! -L "$path" ]] || continue
			while IFS= read -r file; do
				is_managed_path "$file" || is_ignored "$file" || printf '%s %s\n' "$kind" "$name/${file#"$path"/}"
			done < <(find "$path" \( -type f -o -type l \) 2>/dev/null)
			continue
		fi
		[[ -r "$manifest" ]] && cut -f2 "$manifest" | grep -qxF -- "$name" && continue
		printf '%s %s\n' "$kind" "$name"
	done < <(find "$dir" -mindepth 1 -maxdepth 1 ! -name '.*' 2>/dev/null)
}

# shellcheck disable=SC2016
list_claude_additions() {
	local source="$PRIV_SOURCE/dot_claude/.settings.managed.json"
	local installed="$CLAUDE_DIR/plugins/installed_plugins.json"
	local path name plugin dir
	jq_items "$CLAUDE_DIR/settings.json" --slurpfile source "$source" '
		def items:
			((.hooks // {}) | to_entries[] | .key as $event | .value[]? | (.matcher // "") as $matcher | .hooks[]?
				| {item: "claude-hook \($event)[\($matcher)]: \(.command // .url // .prompt // .type // "")"}),
			((.enabledPlugins // {}) | to_entries[] | {item: "claude-plugin \(.key)", value}),
			((.extraKnownMarketplaces // {}) | keys[] | {item: "claude-marketplace \(.)"}),
			((.mcpServers // {}) | to_entries[] | {item: "claude-mcp \(.key)", value}),
			(.statusLine.command? // empty | {item: "claude-statusline \(.)"}),
			(.subagentStatusLine.command? // empty | {item: "claude-statusline \(.)"}),
			(.fileSuggestion.command? // empty | {item: "claude-file-suggestion \(.)"}),
			(.apiKeyHelper // empty | {item: "claude-api-key-helper \(.)"}),
			((.env // {}) | to_entries[] | {item: "claude-env \(.key)", value});
		([items] - [$source[0] | items])[].item | gsub("[\\n\\r]"; " ")'
	jq_items "$CLAUDE_DIR/plugins/known_marketplaces.json" --slurpfile source "$source" '
		(keys - ($source[0].extraKnownMarketplaces // {} | keys))[] | "claude-marketplace \(.)"'
	jq_items "$HOME/.claude.json" --slurpfile source "$source" '
		def servers: (.mcpServers // {}) | to_entries | map({item: "claude-mcp \(.key)", value});
		((servers - ($source[0] | servers))[].item),
		((.projects // {})[] | .mcpServers // {} | keys[] | "claude-project-mcp \(.)")'
	while IFS=$'\t' read -r plugin dir; do
		if [[ -z "$dir" ]]; then
			printf '%s\n' "$plugin"
			continue
		fi
		jq_items "$dir/hooks/hooks.json" --arg plugin "$plugin" \
			'((.hooks // {}) | keys[]), (.modules // [])[] | "claude-plugin-hook \($plugin) \(.)"'
		jq_items "$dir/.claude-plugin/plugin.json" --arg plugin "$plugin" '
			(select(.hooks) | "claude-plugin-hook \($plugin) manifest"),
			(.mcpServers // empty | if type == "object" then keys[] else tostring end | "claude-plugin-mcp \($plugin) \(.)")'
		jq_items "$dir/.mcp.json" --arg plugin "$plugin" '(.mcpServers // .) | keys[] | "claude-plugin-mcp \($plugin) \(.)"'
	done < <(jq_items "$installed" '(.plugins // {}) | to_entries[] | .key as $plugin | .value[] | "\($plugin)\t\(.installPath // "")"')
	list_unmanaged_children claude-skills "$CLAUDE_DIR/skills" "$PUB_SOURCE/docs/skills.tsv"
	for name in agents rules commands hooks output-styles workflows mods; do
		list_unmanaged_children "claude-$name" "$CLAUDE_DIR/$name"
	done
	while IFS= read -r path; do
		is_managed_path "$path" && continue
		is_ignored "$path" && continue
		printf 'claude-script %s\n' "${path##*/}"
	done < <(find "$CLAUDE_DIR" -mindepth 1 -maxdepth 1 \( -type f -o -type l \) \( -perm +111 -o -name '*.py' -o -name '*.sh' \
		-o -name '*.js' -o -name '*.mjs' -o -name '*.ts' \) 2>/dev/null)
}

list_changed_instructions() {
	local src target pair
	local source_claude="$PRIV_SOURCE/dot_claude" source_pi="$PRIV_SOURCE/dot_pi/agent"
	for pair in "$source_claude/CLAUDE.md:$CLAUDE_DIR/CLAUDE.md" \
		"$source_pi/AGENTS.md:$HOME/.pi/agent/AGENTS.md" \
		"$source_pi/AGENTS.override.md:$HOME/.pi/agent/AGENTS.override.md" \
		"$source_pi/APPEND_SYSTEM.md:$HOME/.pi/agent/APPEND_SYSTEM.md" \
		"$source_pi/CLAUDE.md:$HOME/.pi/agent/CLAUDE.md" \
		"$source_pi/SYSTEM.md:$HOME/.pi/agent/SYSTEM.md"; do
		src=${pair%%:*} target=${pair#*:}
		[[ -e "$target" ]] || continue
		[[ -e "$src" ]] && cmp -s "$src" "$target" && continue
		printf 'instructions %s\n' "${target#"$HOME"/}"
	done
	while IFS= read -r src; do
		case "$src" in
		"$source_claude"/*) target="$CLAUDE_DIR/${src#"$source_claude"/}" ;;
		*) target="$HOME/.pi/agent/${src#"$source_pi"/}" ;;
		esac
		[[ -e "$target" ]] || continue
		cmp -s "$src" "$target" || printf 'instructions %s\n' "${target#"$HOME"/}"
	done < <(
		find "$source_claude/rules" "$source_claude/agents" "$source_pi/rules" "$source_pi/agents" \
			-type f -name '*.md' 2>/dev/null
		find "$source_claude/mods" -mindepth 3 -maxdepth 3 -path '*/hooks/hooks.json' 2>/dev/null
	)
}

# shellcheck disable=SC2016,SC2001
list_pi_additions() {
	local source_pi="$PRIV_SOURCE/dot_pi" managed name escaped
	list_unmanaged_children pi-skills "$HOME/.pi/agent/skills" "$source_pi/skills.tsv"
	for name in extensions agents rules; do
		list_unmanaged_children "pi-$name" "$HOME/.pi/agent/$name"
	done
	managed=$(sed -n "/^managed='{/,/^}'/p" "$source_pi/agent/modify_settings.json" 2>/dev/null | sed -e "s/^managed='//" -e "s/^}'/}/")
	[[ -n "$managed" ]] || managed='{}'
	jq_items "$HOME/.pi/agent/settings.json" --argjson source "$managed" '
		. as $live | ["packages", "extensions", "skills"][] as $key
		| ((($live[$key] // []) | map(if type == "object" then .source else . end)) - ($source[$key] // []))[]
		| "pi-\($key) \(.)"'
	while IFS= read -r name; do
		escaped=$(sed 's/[][\\.*^$()+?{}|]/\\&/g' <<<"$name")
		grep -qE -- "\"$escaped\"[[:space:]]*:[[:space:]]*\{" "$source_pi/agent/mcp.json.tmpl" 2>/dev/null ||
			printf 'pi-mcp %s\n' "$name"
	done < <(jq_items "$HOME/.pi/agent/mcp.json" '(.mcpServers // {}) | keys[]')
}

codex_section_items() {
	sed -nE "s/^\[$1\.(\"([^\"]+)\"|'([^']+)'|([^].\"']+))\]\$/$2 \2\3\4/p"
}

list_codex_additions() {
	local codex="$HOME/.codex" config="$HOME/.codex/config.toml" normal notify name
	if [[ -r "$config" ]]; then
		normal=$(sed -E 's/^[[:space:]]+//; s/^(\[[^#]*\])[[:space:]]*#.*$/\1/; s/[[:space:]]+$//' "$config")
		codex_section_items marketplaces codex-marketplace <<<"$normal"
		codex_section_items mcp_servers codex-mcp <<<"$normal"
		codex_section_items plugins codex-plugin <<<"$normal"
		codex_section_items agents codex-agent <<<"$normal"
		grep -qE '^\[\[?hooks[].]' <<<"$normal" && printf 'codex-hooks config\n'
		notify=$(sed -nE '/^notify[[:space:]]*=/,/\]/p' <<<"$normal" | tr -d '\n' | tr "'" '"' |
			sed -E 's/^[^[]*\[//; s/\][^]]*$//; s/,[[:space:]]*$//; s/[[:space:]]*,[[:space:]]*/, /g; s/^[[:space:]]+//')
		[[ -z "$notify" ]] || printf 'codex-notify %s\n' "$notify"
	fi
	for name in AGENTS.md AGENTS.override.md; do
		[[ -e "$codex/$name" ]] && printf 'codex-instructions %s\n' "$name"
	done
	[[ -e "$codex/hooks.json" ]] && printf 'codex-hooks hooks.json\n'
	for name in skills rules agents; do
		list_unmanaged_children "codex-$name" "$codex/$name"
	done
}

check_additions() {
	local reason=''
	command -v jq >/dev/null 2>&1 || reason='jq missing'
	[[ -r "$PRIV_SOURCE/dot_claude/.settings.managed.json" ]] || reason='dot_claude/.settings.managed.json unreadable'
	[[ -s "$MANAGED_FILE" ]] || reason='chezmoi managed list empty'
	if [[ -n "$reason" ]]; then
		log "  WARN: agent addition: check skipped ($reason)"
		return 1
	fi
	local item found=0
	while IFS= read -r item; do
		[[ -n "$item" ]] || continue
		grep -qxF -- "$item" "$ADDITIONS_FILE" 2>/dev/null && continue
		log "  WARN: agent addition: $item - remove it, or add this item to docs/agent-additions.txt"
		found=$((found + 1))
	done < <(
		{
			list_claude_additions
			list_changed_instructions
			list_unmanaged_children shared-skills "$HOME/.agents/skills" "$PUB_SOURCE/docs/skills.tsv"
			list_pi_additions
			list_codex_additions
		} | LC_ALL=C tr -cd '[:print:]\n' | sort -u
	)
	[[ "$found" -eq 0 ]] && log '  clean'
	[[ "$found" -eq 0 ]]
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
		python3 - "$agents_dir" "$CLAUDE_DIR/markers/subagent-spawns" 4 <<'PYEOF'
import calendar, glob, json, os, sys, time

agents_dir, log_dir, cap = sys.argv[1], sys.argv[2], int(sys.argv[3])
names = sorted(f[:-3] for f in os.listdir(agents_dir) if f.endswith(".md"))
window, now = 30 * 86400, time.time()
issues = []

if len(names) > cap:
    issues.append("%d user agents exceed the cap of %d" % (len(names), cap))

spawns = {}
for log_path in glob.glob(os.path.join(log_dir, "*.jsonl")):
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
	[[ -f "$PRIV_SOURCE/dot_claude/.settings.managed.json" ]] || {
		err "missing $PRIV_SOURCE/dot_claude/.settings.managed.json"
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

	log '[5/5] lint (enabledPlugins/mcpServers shape, CC version, skill name, skill layers)'
	check_lint
	rc5=$?
	log ''

	local total=$((rc1 + rc2 + rc3 + rc4 + rc5))
	log "Total issues: $total"

	log '[warn 1/8] first-party plugin drift (installed sha vs claude-code-plugins origin/main)'
	check_plugin_src_drift
	log ''

	log '[warn 2/8] cavemem health (hook, better-sqlite3, embedder, worker)'
	check_cavemem_abi
	log ''

	log '[warn 3/8] safeguard toggle (switchModelsOnFlag=false in source + live settings.json)'
	check_safeguard_toggle
	log ''

	log '[warn 4/8] user agents (cap of 4, 0-spawn-in-30d staleness via markers/subagent-spawns/)'
	check_user_agents
	log ''

	log '[warn 5/8] rig version gate (validate, type check and tests after a Claude Code update)'
	check_rig_gate
	log ''

	log '[warn 6/8] AI release stores (Codex daemon and Pi keep at most two releases)'
	check_ai_releases
	log ''

	log '[warn 7/8] dangling links (~/.bin and ~/.claude/skills)'
	check_links
	log ''

	log '[warn 8/8] agent additions (Claude, Pi and Codex items outside the source and docs/agent-additions.txt)'
	check_additions
	log ''

	[[ "$total" -eq 0 ]]
}

write_warnings() {
	local warnings=$1 tmp=''
	local file="$CLAUDE_DIR/markers/doctor-warnings.txt"
	if [[ -z "$warnings" ]]; then
		rm -f "$file"
		return 0
	fi
	mkdir -p "${file%/*}" && tmp=$(mktemp "$file.XXXXXX") && printf '%s\n' "$warnings" >"$tmp" && mv "$tmp" "$file" && return 0
	[[ -z "$tmp" ]] || rm -f "$tmp"
	return 1
}

rewake_additions() {
	local kept added
	kept=$(grep -v '^agent addition: ' "$CLAUDE_DIR/markers/doctor-warnings.txt" 2>/dev/null)
	added=$(check_additions | sed -nE 's/^[[:space:]]*WARN: //p')
	write_warnings "$(printf '%s\n%s\n' "$kept" "$added" | sed '/^$/d')"
}

rewake_finish() {
	local rc=$1 report=$2
	write_warnings "$(sed -nE 's/^[[:space:]]*WARN: //p' <<<"$report")" || rm -f "$CLAUDE_DIR/markers/doctor-warnings.txt"
	[[ "$rc" -eq 0 ]] && return 0
	{
		printf 'chezmoi-claude-doctor: issues found. Run ~/.bin/chezmoi-claude-doctor.sh for the full report.\n'
		printf '%s\n' "$report"
	} >&2
	return 2
}

self_test() {
	local mk_md="$CLAUDE_DIR/.doctor-test.md"
	local mk_in_dir="$CLAUDE_DIR/agents/.doctor-test-orphan.tmp"
	local worktree out line seen
	OUTSIDE_DIR=$(mktemp -d -t chezmoi-claude-doctor-outside.XXXXXX) || return 1

	log '[test] phase 1: rewake scope'
	if ! rewake_applies "$PUB_SOURCE"; then
		err '[test] FAIL: rewake skipped in the source repository'
		return 1
	fi
	if ! rewake_applies "$PUB_SOURCE/dot_claude"; then
		err '[test] FAIL: rewake skipped in a source submodule'
		return 1
	fi
	worktree=""
	seen=0
	while IFS= read -r line; do
		[[ "$line" == worktree\ * ]] || continue
		seen=$((seen + 1))
		[[ "$seen" -eq 1 ]] && continue
		worktree="${line#worktree }"
		break
	done < <(git -C "$PUB_SOURCE" worktree list --porcelain 2>/dev/null)
	if [[ -z "$worktree" ]]; then
		log '[test]   skip: the source repository has no linked worktree'
	elif ! rewake_applies "$worktree"; then
		err "[test] FAIL: rewake skipped in worktree $worktree"
		return 1
	fi
	if rewake_applies "$OUTSIDE_DIR"; then
		err '[test] FAIL: rewake ran outside the source repository'
		return 1
	fi
	if rewake_applies ""; then
		err '[test] FAIL: rewake treated an empty cwd as the source repository'
		return 1
	fi
	if ! out=$(cd "$OUTSIDE_DIR" && env -u CLAUDE_JOB_DIR "$SELF" --rewake 2>&1 </dev/null) || [[ -n "$out" ]]; then
		err '[test] FAIL: --rewake outside the source repository must exit 0 and stay silent'
		return 1
	fi
	if ! out=$(cd "$PUB_SOURCE" && printf '{"cwd":"%s"}' "$OUTSIDE_DIR" | env -u CLAUDE_JOB_DIR "$SELF" --rewake 2>&1) || [[ -n "$out" ]]; then
		err '[test] FAIL: --rewake must obey an outside cwd in the stdin payload'
		return 1
	fi
	rmdir "$OUTSIDE_DIR"
	OUTSIDE_DIR=""
	if ! (
		CLAUDE_DIR=$(mktemp -d -t chezmoi-claude-doctor-job.XXXXXX)
		export CLAUDE_DIR
		trap 'rm -rf "$CLAUDE_DIR"' EXIT
		marker="$CLAUDE_DIR/markers/doctor-warnings.txt"
		mkdir -p "${marker%/*}"
		printf 'stale\n' >"$marker"
		out=$(cd "$PUB_SOURCE" && CLAUDE_JOB_DIR="$CLAUDE_DIR" "$SELF" --rewake 2>&1 </dev/null) || exit 1
		[[ -z "$out" && "$(cat "$marker")" == stale ]] || exit 1
		out=$(cd "$PUB_SOURCE" && env -u CLAUDE_JOB_DIR "$SELF" --rewake 2>&1 </dev/null)
		[[ -n "$out" || "$(cat "$marker" 2>/dev/null)" != stale ]]
	); then
		err '[test] FAIL: --rewake must skip a background session and still run in a terminal session'
		return 1
	fi

	log '[test] phase 2: clean baseline'
	if ! "$SELF" --quiet >/dev/null 2>&1; then
		err '[test] FAIL: pre-existing drift; full report:'
		"$SELF" >&2 || true
		return 1
	fi

	log '[test] phase 3: synthesize top-level *.md orphan'
	: >"$mk_md"
	build_managed >"$MANAGED_FILE" # rebuild (managed list unchanged but be safe)
	if "$SELF" --quiet >/dev/null 2>&1; then
		rm -f "$mk_md"
		err '[test] FAIL: shape check missed top-level *.md orphan'
		return 1
	fi
	rm -f "$mk_md"

	log '[test] phase 4: synthesize file inside managed dir (~/.claude/agents/)'
	: >"$mk_in_dir"
	if "$SELF" --quiet >/dev/null 2>&1; then
		rm -f "$mk_in_dir"
		err '[test] FAIL: coverage check missed orphan in managed dir'
		return 1
	fi
	rm -f "$mk_in_dir"

	log '[test] phase 5: clean state restored'
	if ! "$SELF" --quiet >/dev/null 2>&1; then
		err '[test] FAIL: doctor still reports drift after cleanup'
		return 1
	fi

	log '[test] phase 6: with no issues, rewake sends WARN lines to the operator file, not to the model'
	if ! (
		CLAUDE_DIR=$(mktemp -d -t chezmoi-claude-doctor-rewake.XXXXXX)
		trap 'rm -rf "$CLAUDE_DIR"' EXIT
		out=$(rewake_finish 0 $'[warn 1/4] x\n  WARN: drift one\nTotal issues: 0' 2>&1) || exit 1
		[[ -z "$out" && "$(cat "$CLAUDE_DIR/markers/doctor-warnings.txt")" == "drift one" ]] || exit 1
		rewake_finish 0 'Total issues: 0' 2>/dev/null || exit 1
		[[ ! -e "$CLAUDE_DIR/markers/doctor-warnings.txt" ]] || exit 1
		out=$(rewake_finish 1 '  LINT: bad key' 2>&1)
		[[ $? -eq 2 && "$out" == *'LINT: bad key'* ]]
	); then
		err '[test] FAIL: rewake must wake the model on issues only and keep WARN lines in the operator file'
		return 1
	fi

	log '[test] phase 7: plugin drift reads origin/main'
	if ! (
		CLAUDE_DIR=$(mktemp -d -t chezmoi-claude-doctor-drift.XXXXXX)
		OWN_PLUGIN_SRC="$CLAUDE_DIR/src"
		trap 'rm -rf "$CLAUDE_DIR"' EXIT
		QUIET=0
		git init -q "$OWN_PLUGIN_SRC"
		g() { git -C "$OWN_PLUGIN_SRC" -c user.email=t@t -c user.name=t "$@"; }
		put() { mkdir -p "$OWN_PLUGIN_SRC/${1%/*}" && echo "$2" >"$OWN_PLUGIN_SRC/$1" && g add "$1"; }
		g commit -q --allow-empty -m one && c1=$(g rev-parse HEAD)
		put plugins/whetstone/SKILL.md two && g commit -q -m two && c2=$(g rev-parse HEAD)
		put plugins/whetstone/CHANGELOG.md three && put tools/test.sh three && g commit -q -m three && c3=$(g rev-parse HEAD)
		mkdir -p "$CLAUDE_DIR/plugins"
		installed() { printf '{"plugins":{"whetstone@raisedadead-plugins":[{"gitCommitSha":"%s"}]}}' "$1" >"$CLAUDE_DIR/plugins/installed_plugins.json"; }
		g update-ref refs/remotes/origin/main "$c1"
		installed "$c1"
		[[ "$(check_plugin_src_drift)" != *WARN* ]] || exit 1
		g update-ref refs/remotes/origin/main "$c2"
		[[ "$(check_plugin_src_drift)" == *'WARN: whetstone@raisedadead-plugins'*'origin/main'* ]] || exit 1
		installed "$c2"
		g update-ref refs/remotes/origin/main "$c3"
		[[ "$(check_plugin_src_drift)" != *WARN* ]] || exit 1
		installed 0123456789abcdef0123456789abcdef01234567
		[[ "$(check_plugin_src_drift)" != *WARN* ]] || exit 1
		installed "$c1"
		g update-ref -d refs/remotes/origin/main
		out=$(check_plugin_src_drift)
		[[ "$out" != *WARN* && "$out" == *'has no origin/main'* ]]
	); then
		err '[test] FAIL: plugin drift must warn only when origin/main changes the plugin files after the install'
		return 1
	fi

	log '[test] phase 8: version gate re-tests the rig when the host types name a new Claude Code version'
	if ! (
		CLAUDE_DIR=$(mktemp -d) || exit 1
		trap 'rm -rf "$CLAUDE_DIR"' EXIT
		types="$CLAUDE_DIR/mods/rig/.claude-plugin/types/claude-code"
		marker="$CLAUDE_DIR/markers/rig-verified-version"
		mkdir -p "$types" "${marker%/*}"
		rig_gate_run() {
			: >"$CLAUDE_DIR/ran"
			return "$gate_rc"
		}
		printf '// Written by Claude Code 9.9.1.\n' >"$types/index.d.ts"
		printf '9.9.1\n' >"$marker"
		gate_rc=1
		out=$(check_rig_gate)
		[[ "$out" != *WARN* && ! -e "$CLAUDE_DIR/ran" ]] || exit 1
		printf '// Written by Claude Code 9.9.2.\n' >"$types/index.d.ts"
		out=$(check_rig_gate)
		[[ "$out" == *'WARN: '*'9.9.2'* && "$(cat "$marker")" == 9.9.1 && -e "$CLAUDE_DIR/ran" ]] || exit 1
		gate_rc=0
		out=$(check_rig_gate)
		[[ "$out" != *WARN* && "$(cat "$marker")" == 9.9.2 ]]
	); then
		err '[test] FAIL: version gate must re-test only on a new version and record the version only after a pass'
		return 1
	fi

	log '[test] phase 9: release stores warn above two releases'
	if ! (
		root=$(mktemp -d) || exit 1
		trap 'rm -rf "$root"' EXIT
		CODEX_RELEASES="$root/c" PI_RELEASES="$root/p"
		mkdir -p "$CODEX_RELEASES"/{r1,r2} "$PI_RELEASES"/{r1,r2}
		out=$(check_ai_releases) || exit 1
		[[ "$out" != *WARN* ]] || exit 1
		mkdir "$PI_RELEASES/r3"
		out=$(check_ai_releases) && exit 1
		[[ "$out" == *"WARN: $PI_RELEASES holds 3 releases"* ]] || exit 1
		[[ "$out" != *"WARN: $CODEX_RELEASES"* ]] || exit 1
		rm -rf "$CODEX_RELEASES" "$PI_RELEASES/r3"
		out=$(check_ai_releases) || exit 1
		[[ "$out" != *WARN* && "$out" == *skip* ]]
	); then
		err '[test] FAIL: release stores must warn only above two releases and skip a missing store'
		return 1
	fi

	log '[test] phase 10: a link to a missing file warns'
	if ! (
		HOME=$(mktemp -d) || exit 1
		trap 'rm -rf "$HOME"' EXIT
		CLAUDE_DIR="$HOME/.claude"
		mkdir -p "$HOME/.bin" "$CLAUDE_DIR/skills" "$HOME/.agents/skills/ok"
		ln -s /bin/sh "$HOME/.bin/ok"
		ln -s ../../.agents/skills/ok "$CLAUDE_DIR/skills/ok"
		out=$(check_links) || exit 1
		[[ "$out" != *WARN* ]] || exit 1
		ln -s "$HOME/missing" "$HOME/.bin/gone"
		ln -s ../../.agents/skills/gone "$CLAUDE_DIR/skills/gone"
		out=$(check_links) && exit 1
		[[ "$out" == *'WARN: ~/.bin/gone points to a missing'* ]] || exit 1
		[[ "$out" == *'WARN: ~/.claude/skills/gone points to a missing'* ]]
	); then
		err '[test] FAIL: links must warn only when the target is missing'
		return 1
	fi

	log '[test] phase 11: an agent item outside the source and the approved list warns'
	if ! (
		HOME=$(mktemp -d) || exit 1
		trap 'rm -rf "$HOME"' EXIT
		QUIET=0
		IGNORED_PATTERNS=()
		CLAUDE_DIR="$HOME/.claude" PUB_SOURCE="$HOME/src" PRIV_SOURCE="$HOME/src"
		ADDITIONS_FILE="$HOME/src/docs/agent-additions.txt"
		MANAGED_FILE="$HOME/managed"
		rig="$CLAUDE_DIR/mods/rig"
		mkdir -p "$HOME/src/dot_claude/mods/rig/hooks" "$HOME/src/dot_pi/agent" "$HOME/src/docs" "$CLAUDE_DIR/skills" \
			"$CLAUDE_DIR/plugins" "$CLAUDE_DIR/rules/sub" "$rig/hooks" "$HOME/plugin/hooks" "$HOME/plugin/.claude-plugin" \
			"$HOME/.agents/skills" "$HOME/.pi/agent/extensions" "$HOME/.codex/rules"
		managed='{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"ok"}]}]},"enabledPlugins":{"good@m":true},"extraKnownMarketplaces":{"m":{}},"env":{"KEEP":"a"},"mcpServers":{"srv":{"url":"a"}}}'
		printf '%s' "$managed" >"$HOME/src/dot_claude/.settings.managed.json"
		printf '%s' "$managed" >"$CLAUDE_DIR/settings.json"
		printf 'kernel\n' >"$HOME/src/dot_claude/CLAUDE.md"
		printf 'kernel\n' >"$CLAUDE_DIR/CLAUDE.md"
		printf '{}' >"$HOME/src/dot_claude/mods/rig/hooks/hooks.json"
		printf '{}' >"$rig/hooks/hooks.json"
		printf '{"mcpServers":{"good":{"command":"x"}}}' >"$HOME/src/dot_pi/agent/mcp.json.tmpl"
		printf '{"mcpServers":{"srv":{"url":"a"}},"projects":{}}' >"$HOME/.claude.json"
		: >"$ADDITIONS_FILE"
		printf '%s\n' "$CLAUDE_DIR/rules/sub" "$rig" "$rig/hooks" "$rig/hooks/hooks.json" >"$MANAGED_FILE"
		out=$(check_additions) || exit 1
		[[ "$out" != *WARN* ]] || exit 1

		printf '%s' '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"ok"}]},{"matcher":"evil","hooks":[{"type":"command","command":"ok"}]}],"FileChanged":[{"hooks":[{"type":"command","command":"evil"}]}]},"enabledPlugins":{"good@m":true,"evil@m":true,"bad\u001bname@m":true},"extraKnownMarketplaces":{"m":{},"evil":{}},"statusLine":{"command":"evil"},"fileSuggestion":{"command":"evil"},"subagentStatusLine":{"command":"evil-sub"},"env":{"KEEP":"b","EVIL_URL":"x"},"mcpServers":{"srv":{"url":"b"}}}' >"$CLAUDE_DIR/settings.json"
		printf '{"mcpServers":{"srv":{"url":"a"},"evil-user":{}},"projects":{"/p":{"mcpServers":{"evil":{}}}}}' >"$HOME/.claude.json"
		printf '{"hooks":{"Stop":[]},"modules":["./evil.tsx"]}' >"$HOME/plugin/hooks/hooks.json"
		printf '{"mcpServers":{"evil-manifest":{}}}' >"$HOME/plugin/.claude-plugin/plugin.json"
		printf '{"mcpServers":{"evil-file":{}}}' >"$HOME/plugin/.mcp.json"
		printf '{"plugins":{"evil@m":[{"installPath":"%s"},{"installPath":"%s"}]}}' "$HOME/none" "$HOME/plugin" >"$CLAUDE_DIR/plugins/installed_plugins.json"
		ln -s ../../.agents/skills/evil "$CLAUDE_DIR/skills/evil"
		mkdir "$HOME/.agents/skills/evil"
		printf '#!/bin/sh\n' >"$CLAUDE_DIR/evil.py"
		ln -s /tmp/x "$CLAUDE_DIR/evil-link.sh"
		printf 'injected\n' >>"$CLAUDE_DIR/CLAUDE.md"
		: >"$CLAUDE_DIR/rules/sub/evil.md"
		printf '{"modules":["evil"]}' >"$rig/hooks/hooks.json"
		: >"$HOME/.pi/agent/extensions/evil.ts"
		: >"$HOME/.pi/agent/SYSTEM.md"
		printf '{"packages":["npm:evil"],"extensions":["/tmp/evil.ts"],"skills":["/tmp/evilskill"]}' >"$HOME/.pi/agent/settings.json"
		printf '{"mcpServers":{"good":{},"command":{}}}' >"$HOME/.pi/agent/mcp.json"
		printf "notify = [\n  '/bin/evil',\n  \"arg\",\n]\n[marketplaces.evil]\n[mcp_servers.\"evil.dot\"] # note\n  [mcp_servers.evil_indent]\n[[hooks.Stop]]\n[plugins.'lit@other']\n[agents.evil]\n" >"$HOME/.codex/config.toml"
		: >"$HOME/.codex/AGENTS.md"
		: >"$HOME/.codex/AGENTS.override.md"
		: >"$HOME/.codex/rules/evil.rules"
		out=$(check_additions) && exit 1
		for item in 'claude-hook FileChanged[]: evil' 'claude-hook Stop[evil]: ok' 'claude-plugin evil@m' \
			'claude-marketplace evil' 'claude-statusline evil' 'claude-statusline evil-sub' 'claude-file-suggestion evil' 'claude-env EVIL_URL' \
			'claude-env KEEP' 'claude-mcp srv' 'claude-mcp evil-user' 'claude-project-mcp evil' \
			'claude-plugin-hook evil@m Stop' 'claude-plugin-hook evil@m ./evil.tsx' \
			'claude-plugin-mcp evil@m evil-manifest' 'claude-plugin-mcp evil@m evil-file' 'claude-skills evil' \
			'claude-rules sub/evil.md' 'claude-script evil.py' 'claude-script evil-link.sh' \
			'instructions .claude/CLAUDE.md' 'instructions .claude/mods/rig/hooks/hooks.json' \
			'instructions .pi/agent/SYSTEM.md' 'shared-skills evil' 'pi-extensions evil.ts' \
			'pi-packages npm:evil' 'pi-extensions /tmp/evil.ts' 'pi-skills /tmp/evilskill' 'pi-mcp command' \
			'codex-notify "/bin/evil", "arg"' 'codex-marketplace evil' 'codex-mcp evil.dot' 'codex-mcp evil_indent' \
			'codex-plugin lit@other' 'codex-agent evil' 'codex-hooks config' 'codex-rules evil.rules' \
			'codex-instructions AGENTS.md' 'codex-instructions AGENTS.override.md'; do
			[[ "$out" == *"WARN: agent addition: $item - "* ]] || {
				err "[test] missing: $item"
				exit 1
			}
		done
		[[ "$out" != *$'\e'* && "$out" != *'pi-mcp good'* ]] || exit 1

		sed -nE 's/^ *WARN: agent addition: (.*) - remove it.*/\1/p' <<<"$out" >"$ADDITIONS_FILE"
		out=$(check_additions) || exit 1
		[[ "$out" != *WARN* ]] || exit 1

		printf 'not json' >"$CLAUDE_DIR/settings.json"
		out=$(check_additions) && exit 1
		[[ "$out" == *'WARN: agent addition: unreadable .claude/settings.json - '* ]] || exit 1
		: >"$MANAGED_FILE"
		out=$(check_additions) && exit 1
		[[ "$out" == *'WARN: agent addition: check skipped'* ]]
	); then
		err '[test] FAIL: agent additions must warn until they are removed or approved'
		return 1
	fi

	log '[test] phase 12: outside the source repository, rewake updates only the agent addition lines'
	if ! (
		CLAUDE_DIR=$(mktemp -d) || exit 1
		trap 'rm -rf "$CLAUDE_DIR"' EXIT
		QUIET=0
		marker="$CLAUDE_DIR/markers/doctor-warnings.txt"
		mkdir -p "${marker%/*}"
		printf 'other warning\nagent addition: old\n' >"$marker"
		check_additions() {
			log '  WARN: agent addition: new'
			return 1
		}
		rewake_additions || exit 1
		[[ "$(cat "$marker")" == $'other warning\nagent addition: new' ]] || exit 1
		check_additions() { log '  clean'; }
		rewake_additions || exit 1
		[[ "$(cat "$marker")" == 'other warning' ]] || exit 1
		printf 'agent addition: old\n' >"$marker"
		rewake_additions || exit 1
		[[ ! -e "$marker" ]]
	); then
		err '[test] FAIL: rewake outside the source repository must keep the other warnings'
		return 1
	fi

	log '[test] PASS'
	return 0
}

OUTSIDE_REPO=0
FAIL_RC=2
if [[ "$MODE" == "rewake" ]]; then
	[[ -z "${CLAUDE_JOB_DIR:-}" ]] || exit 0
	if ! rewake_applies "$(session_cwd)"; then
		OUTSIDE_REPO=1
		FAIL_RC=0
		exec 2>/dev/null
	fi
fi

require chezmoi
require find
require sed
require grep
require sort

OUTSIDE_DIR=""
MANAGED_FILE=$(mktemp -t chezmoi-claude-doctor.XXXXXX) || exit "$FAIL_RC"
trap 'rm -f "$MANAGED_FILE"; [[ -n "$OUTSIDE_DIR" ]] && rmdir "$OUTSIDE_DIR" 2>/dev/null' EXIT

build_managed >"$MANAGED_FILE"
load_ignored

if [[ "$OUTSIDE_REPO" -eq 1 ]]; then
	rewake_additions
	exit 0
fi

if [[ "$MODE" == "test" ]]; then
	self_test
	exit $?
fi

if [[ "$MODE" == "rewake" ]]; then
	report=$(run_checks 2>&1)
	rewake_finish "$?" "$report"
	exit $?
fi

run_checks
exit $?
