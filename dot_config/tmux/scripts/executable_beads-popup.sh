#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091,SC2034

. "$(dirname "$0")/colors.sh"

pane_path="${1:-$(pwd)}"

find_beads_dir() {
  local dir="$1"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/.beads" ]]; then
      printf '%s/.beads' "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

beads_dir=$(find_beads_dir "$pane_path" || true)
if [[ -n "$beads_dir" ]]; then
  export BEADS_DIR="$beads_dir"
  bd list --watch --limit=0 || true
else
  printf '\n  %sNothing to show for this project.%s\n\n' "$CLR_DIM" "$CLR_RST"
  read -r -s -n1
fi
