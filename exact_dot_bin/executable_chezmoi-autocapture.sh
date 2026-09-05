#!/bin/bash
set -euo pipefail

source_dir=$(chezmoi source-path)
git_dir=$(git -C "$source_dir" rev-parse --absolute-git-dir)

for marker in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply; do
	if [ -e "$git_dir/$marker" ]; then
		printf 'autocapture: %s present, skipped\n' "$marker"
		exit 0
	fi
done

targets=()
while IFS= read -r line; do
	[ "${line:1:1}" = "M" ] || continue
	targets+=("$HOME/${line:3}")
done < <(chezmoi status)

[ ${#targets[@]} -gt 0 ] || exit 0

chezmoi re-add --no-tty --no-pager "${targets[@]}"

leaked=0
while IFS= read -r line; do
	path=${line##* }
	[ -f "$source_dir/$path" ] || continue
	if ! report=$(gitleaks dir "$source_dir/$path" -c "$source_dir/.gitleaks.toml" --redact --no-banner 2>&1); then
		printf 'autocapture: captured secret in %s\n%s\n' "$path" "$report" >&2
		leaked=1
	fi
done < <(git -C "$source_dir" status --porcelain)

exit "$leaked"
