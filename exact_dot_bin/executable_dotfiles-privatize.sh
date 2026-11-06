#!/usr/bin/env bash

set -euo pipefail

SOURCE="${PRIV_SOURCE:-$HOME/.dotfiles}"
REMOTE=""
PUSH=0
DIR=""

usage() {
	printf 'usage: dotfiles-privatize.sh <dir> [--push] [--remote <url>] [--source <path>]\n'
	printf '  moves <dir> to a submodule backed by branch <dir> of the private repo\n'
	printf '  the remote defaults to the first submodule url in .gitmodules\n'
	printf '  without --push it prepares the branches and prints the remaining commands\n'
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--push) PUSH=1 ;;
	--remote)
		REMOTE="${2:?--remote needs a url}"
		shift
		;;
	--source)
		SOURCE="${2:?--source needs a path}"
		shift
		;;
	--help | -h)
		usage
		exit 0
		;;
	-*)
		printf 'unknown flag: %s\n' "$1" >&2
		exit 2
		;;
	*) DIR="${1%/}" ;;
	esac
	shift
done

PUSHED=0

die() {
	printf 'dotfiles-privatize: %s\n' "$*" >&2
	((PUSHED)) && pushed_hint
	exit 1
}

[[ -n "$DIR" ]] || {
	usage >&2
	exit 2
}
cd "$SOURCE" || die "no source at $SOURCE"
[[ -d "$DIR" ]] || die "not a directory: $DIR"
mode="$(git ls-tree -d HEAD "$DIR" | awk '{print $1}')"
[[ -n "$mode" ]] || die "not tracked: $DIR"
[[ "$mode" != 160000 ]] || die "already a submodule: $DIR"
[[ -z "$(git status --porcelain)" ]] || die 'working tree is not clean'
if [[ -f .gitmodules ]]; then
	while read -r sub; do
		case "$DIR/" in
		"$sub"/*) die "inside submodule $sub" ;;
		esac
		case "$sub/" in
		"$DIR"/*) die "contains submodule $sub" ;;
		esac
	done < <(git config -f .gitmodules --get-regexp 'submodule\..*\.path' | awk '{print $2}')
fi
if [[ -z "$REMOTE" ]]; then
	REMOTE="$(git config -f .gitmodules --get-regexp 'submodule\..*\.url' 2>/dev/null |
		awk 'NR==1 {print $2}')" || true
fi
[[ -n "$REMOTE" ]] || die 'no remote: pass --remote <url>'
command -v gitleaks >/dev/null || die 'gitleaks not found'
[[ -f .gitleaks.toml && -f .githooks/pre-commit && -f .githooks/post-commit ]] ||
	die 'missing .gitleaks.toml, .githooks/pre-commit, or .githooks/post-commit'

BRANCH="$DIR"
TMP_BRANCH="privatize/$DIR"
git ls-remote --exit-code "$REMOTE" "refs/heads/$BRANCH" >/dev/null 2>&1 && rc=0 || rc=$?
case "$rc" in
0) die "branch $BRANCH already exists on $REMOTE" ;;
2) ;;
*) die "cannot reach $REMOTE (git ls-remote exit $rc)" ;;
esac
git show-ref --verify -q "refs/heads/$TMP_BRANCH" && die "stale branch $TMP_BRANCH; delete it first"

printf 'plan\n  dir     %s\n  branch  %s\n  remote  %s\n  push    %s\n' \
	"$DIR" "$BRANCH" "$REMOTE" "$PUSH"

split_log="$(git subtree split --prefix="$DIR" -b "$TMP_BRANCH" 2>&1)" ||
	die "subtree split failed: ${split_log##*$'\n'}"
[[ "$(git rev-parse "$TMP_BRANCH^{tree}")" == "$(git rev-parse "HEAD:$DIR")" ]] ||
	die 'split tree differs from HEAD tree'

repath() {
	local line out=""
	[[ -f "$1" ]] || return 0
	while IFS= read -r line; do
		[[ "$line" == "$DIR/"* ]] && out+="${line#"$DIR"/}"$'\n'
	done <"$1"
	printf '%s' "$out"
}

IGNORE_FILE="$(mktemp)"
trap 'rm -f "$IGNORE_FILE"' EXIT
repath .gitleaksignore >"$IGNORE_FILE"

root_tree() {
	local entries entry rules pre post hooks_tree
	entries="$(git ls-tree "$TMP_BRANCH" |
		grep -vE $'\t(\.gitleaks\.toml|\.gitleaksignore|\.gitignore|\.githooks)$' || true)"
	entry="$(printf '100644 blob %s\t.gitleaks.toml' "$(git hash-object -w .gitleaks.toml)")"
	entries="$entries"$'\n'"$entry"
	if [[ -s "$IGNORE_FILE" ]]; then
		entry="$(printf '100644 blob %s\t.gitleaksignore' "$(git hash-object -w "$IGNORE_FILE")")"
		entries="$entries"$'\n'"$entry"
	fi
	rules="$(repath .gitignore)"
	if [[ -n "$rules" ]]; then
		entry="$(printf '100644 blob %s\t.gitignore' \
			"$(printf '%s' "$rules" | git hash-object -w --stdin)")"
		entries="$entries"$'\n'"$entry"
	fi
	pre="$(git hash-object -w .githooks/pre-commit)"
	post="$(git hash-object -w .githooks/post-commit)"
	hooks_tree="$(printf '100755 blob %s\tpre-commit\n100755 blob %s\tpost-commit\n' "$pre" "$post" | git mktree)"
	entry="$(printf '040000 tree %s\t.githooks' "$hooks_tree")"
	entries="$entries"$'\n'"$entry"
	printf '%s\n' "$entries" | git mktree
}

root_commit="$(git commit-tree "$(root_tree)" -p "$TMP_BRANCH" \
	-m 'chore: add gitleaks config and git hooks')"
git branch -f "$TMP_BRANCH" "$root_commit"
gitleaks git . --log-opts="$TMP_BRANCH" --gitleaks-ignore-path "$IGNORE_FILE" \
	--redact --no-banner --exit-code 1 >/dev/null 2>&1 ||
	die "secret on $TMP_BRANCH, branch kept; run: gitleaks git . --log-opts=$TMP_BRANCH"

target() {
	chezmoi --source "$SOURCE" target-path "$DIR" 2>/dev/null | sed "s|^$HOME|~|" || printf '?'
}

readme_commit() {
	local base readme row tree
	base="$(git ls-remote "$REMOTE" main | awk '{print $1}')"
	[[ -n "$base" ]] || die "no main on $REMOTE"
	git fetch -q "$REMOTE" main
	git cat-file -e "$base:README.md" 2>/dev/null || die "no README.md on main of $REMOTE"
	readme="$(git show "$base:README.md")"
	row="$(printf "| [\`%s\`](../../tree/%s) | \`%s/\` | \`%s\` |" \
		"$BRANCH" "$BRANCH" "$DIR" "$(target)")"
	printf '%s\n' "$readme" | grep -q '^| \[`' || die 'no table row in README.md'
	readme="$(printf '%s\n' "$readme" | awk -v row="$row" '
		/^\| \[`/ { last = NR }
		{ lines[NR] = $0 }
		END {
			for (i = 1; i <= NR; i++) {
				print lines[i]
				if (i == last) print row
			}
		}')"
	tree="$( (
		git ls-tree "$base" | grep -v $'\tREADME.md$' || true
		printf '100644 blob %s\tREADME.md\n' \
			"$(printf '%s\n' "$readme" | git hash-object -w --stdin)"
	) | git mktree)"
	git commit-tree "$tree" -p "$base" -m "docs: index $BRANCH"
}
docs_commit="$(readme_commit)"

pushed_hint() {
	printf 'dotfiles-privatize: remote %s already holds branch %s\n' "$REMOTE" "$BRANCH" >&2
	printf '  finish by hand from the printed plan, or delete the branch on the remote\n' >&2
}

if ((PUSH)); then
	git push -q "$REMOTE" "$TMP_BRANCH:refs/heads/$BRANCH"
	PUSHED=1
	trap 'pushed_hint' ERR
	git push -q "$REMOTE" "$docs_commit:refs/heads/main"
	git rm -rq "$DIR"
	rm -rf "$DIR"
	git submodule add -q -b "$BRANCH" "$REMOTE" "$DIR"
	git -C "$DIR" config core.hooksPath .githooks
	[[ "$(git -C "$DIR" rev-parse HEAD)" == "$root_commit" ]] || die 'submodule HEAD differs'
	git add .gitmodules "$DIR"
	git commit -q -m "chore($DIR): move to the private submodule"
	git branch -D "$TMP_BRANCH" >/dev/null
	trap - ERR
	PUSHED=0
	printf 'done: %s is the submodule at %s\n' "$DIR" "$(git rev-parse --short HEAD)"
else
	printf 'prepared %s and README commit %s. Run:\n' "$TMP_BRANCH" "${docs_commit:0:7}"
	printf '  git push %s %s:refs/heads/%s\n' "$REMOTE" "$TMP_BRANCH" "$BRANCH"
	printf '  git push %s %s:refs/heads/main\n' "$REMOTE" "$docs_commit"
	printf '  git rm -r %s && rm -rf %s\n' "$DIR" "$DIR"
	printf '  git submodule add -b %s %s %s\n' "$BRANCH" "$REMOTE" "$DIR"
	printf '  git -C %s config core.hooksPath .githooks\n' "$DIR"
	printf '  git add .gitmodules %s && git commit -m "chore(%s): move to the private submodule"\n' \
		"$DIR" "$DIR"
	printf '  git branch -D %s\n' "$TMP_BRANCH"
fi
