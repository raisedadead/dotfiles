#!/usr/bin/env bash
# chezmoi-fixture-check — MAINTENANCE C4: apply a synthetic source to an
# isolated destination and check the deployment boundary. Exits 1 on a failed
# check and 2 on a usage error or a missing chezmoi.
set -euo pipefail
umask 022

usage() {
	printf 'usage: chezmoi-fixture-check.sh [--keep]\n'
	printf '  --keep   leave the fixture directory in place and print its path\n'
}

KEEP=0
case "${1:-}" in
--keep) KEEP=1 ;;
-h | --help)
	usage
	exit 0
	;;
"") ;;
*)
	usage >&2
	exit 2
	;;
esac

command -v chezmoi >/dev/null 2>&1 || {
	printf 'chezmoi-fixture-check: chezmoi not found\n' >&2
	exit 2
}

FX="$(mktemp -d "${TMPDIR:-/tmp}/chezmoi-fixture.XXXXXX")"
cleanup() {
	if ((KEEP)); then
		printf 'fixture kept at %s\n' "$FX"
	else
		rm -rf "$FX"
	fi
}
trap cleanup EXIT

SRC="$FX/source"
DST="$FX/home"
CFG="$FX/config.toml"
STATE="$FX/state.boltdb"
CACHE="$FX/cache"
mkdir -p "$SRC/dot_config/exact_owned" "$SRC/dot_config/shared" "$SRC/docs" "$DST" "$CACHE"
printf 'sourceDir = "%s"\ndestDir = "%s"\n' "$SRC" "$DST" >"$CFG"
printf 'exact one\n' >"$SRC/dot_config/exact_owned/a.conf"
printf 'plain one\n' >"$SRC/dot_config/shared/b.conf"
printf 'secret\n' >"$SRC/private_dot_secret.txt"
printf '#!/bin/sh\n' >"$SRC/executable_dot_run.sh"
printf 'hello {{ "fixture" }}\n' >"$SRC/dot_rendered.txt.tmpl"
printf 'owner doc\n' >"$SRC/docs/README.md"
printf 'docs\n' >"$SRC/.chezmoiignore"

cz() {
	chezmoi --config "$CFG" --source "$SRC" --destination "$DST" \
		--persistent-state "$STATE" --cache "$CACHE" "$@"
}
mode() {
	local m
	m=$(stat -c '%a' "$1" 2>/dev/null) || m=$(stat -f '%Lp' "$1")
	printf '%s\n' "$m"
}
if command -v sha256sum >/dev/null 2>&1; then
	HASH=(sha256sum)
else
	HASH=(shasum -a 256)
fi
snapshot() {
	(cd "$DST" && find . -type f -exec "${HASH[@]}" {} + | sort)
}

FAILED=0
pass() { printf 'PASS %s\n' "$1"; }
fail() {
	printf 'FAIL %s\n' "$1"
	FAILED=$((FAILED + 1))
}

cz apply
if [[ "$(cat "$DST/.config/owned/a.conf")" == "exact one" &&
"$(cat "$DST/.rendered.txt")" == "hello fixture" &&
"$(mode "$DST/.secret.txt")" == 600 &&
"$(mode "$DST/.run.sh")" == 755 ]]; then
	pass '1 selected files render at their paths with the expected permissions'
else
	fail '1 render'
fi

before="$(snapshot)"
cz apply
after="$(snapshot)"
state="$(cz status)"
if [[ "$before" == "$after" && -z "$state" ]]; then
	pass '2 a second apply leaves the state unchanged'
else
	fail '2 second apply'
fi

printf 'keep me\n' >"$DST/.config/shared/extra.conf"
cz apply
if [[ -f "$DST/.config/shared/extra.conf" ]]; then
	pass '3 an unmanaged file outside an exact directory survives'
else
	fail '3 unmanaged survives'
fi

printf 'stray\n' >"$DST/.config/owned/stray.conf"
cz apply
if [[ ! -e "$DST/.config/owned/stray.conf" ]]; then
	pass '4 an extra file inside an exact directory is removed'
else
	fail '4 exact removal'
fi

if [[ ! -e "$DST/docs" ]]; then
	pass '5 an excluded repository document is absent'
else
	fail '5 excluded absent'
fi

printf 'plain edited\n' >"$DST/.config/shared/b.conf"
printf 'sibling\n' >"$DST/.config/shared/c.conf"
printf 'exact edited\n' >"$DST/.config/owned/a.conf"
printf 'sibling\n' >"$DST/.config/owned/new.conf"
cz re-add "$DST/.config/shared/b.conf" "$DST/.config/owned/a.conf"
plain=no
exact=no
[[ -f "$SRC/dot_config/shared/c.conf" ]] && plain=yes
[[ -f "$SRC/dot_config/exact_owned/new.conf" ]] && exact=yes
if [[ "$(cat "$SRC/dot_config/shared/b.conf")" == "plain edited" &&
"$(cat "$SRC/dot_config/exact_owned/a.conf")" == "exact edited" &&
"$plain" == no && "$exact" == yes ]]; then
	pass '6 a named capture takes the named files and an exact sibling, not a plain sibling'
else
	fail "6 named capture: plain sibling captured=$plain exact sibling captured=$exact"
fi

printf 'checks failed: %s\n' "$FAILED"
[[ "$FAILED" -eq 0 ]]
