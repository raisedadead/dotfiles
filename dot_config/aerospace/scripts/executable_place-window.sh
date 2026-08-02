#!/usr/bin/env bash
set -euo pipefail

AEROSPACE=/opt/homebrew/bin/aerospace
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/aerospace"
LOG_FILE="$CACHE_DIR/place-window.log"
LOG_MAX_BYTES=65536
WINDOW_LOOKUP_ATTEMPTS=20
WINDOW_LOOKUP_INTERVAL=0.05
FALLBACK_BOTTOM_INSET=60

usage() {
	printf 'usage: place-window.sh <center|cycle>\n' >&2
	exit 2
}

mode="${1:-center}"
case "$mode" in
center | cycle) ;;
*) usage ;;
esac

mkdir -p "$CACHE_DIR"
if [[ -f "$LOG_FILE" ]] && (($(wc -c <"$LOG_FILE") > LOG_MAX_BYTES)); then
	: >"$LOG_FILE"
fi
exec 2>>"$LOG_FILE"

resolve_window_id() {
	local id="${AEROSPACE_WINDOW_ID:-}"
	if [[ ! "$id" =~ ^[0-9]+$ ]]; then
		id="$("$AEROSPACE" list-windows --focused --format '%{window-id}' 2>/dev/null || true)"
	fi
	[[ "$id" =~ ^[0-9]+$ ]] || return 1
	printf '%s\n' "$id"
}

resolve_window_row() {
	local id="$1" row="" _attempt
	for _attempt in $(seq 1 "$WINDOW_LOOKUP_ATTEMPTS"); do
		row="$("$AEROSPACE" list-windows --all \
			--format '%{window-id}|%{app-pid}|%{monitor-appkit-nsscreen-screens-id}|%{window-title}' 2>/dev/null |
			grep -m1 "^${id}|" || true)"
		[[ -n "$row" ]] && break
		sleep "$WINDOW_LOOKUP_INTERVAL"
	done
	[[ -n "$row" ]] || return 1
	printf '%s\n' "$row"
}

reserved_bottom_inset() {
	local config inset
	config="$("$AEROSPACE" config --config-path 2>/dev/null || true)"
	[[ -f "$config" ]] || config="${XDG_CONFIG_HOME:-$HOME/.config}/aerospace/aerospace.toml"
	inset="$(awk -F'=' '/^outer\.bottom/ {gsub(/[^0-9]/, "", $2); print $2; exit}' "$config" 2>/dev/null || true)"
	[[ "$inset" =~ ^[0-9]+$ ]] || inset="$FALLBACK_BOTTOM_INSET"
	printf '%s\n' "$inset"
}

window_id="$(resolve_window_id)" || exit 0
window_row="$(resolve_window_row "$window_id")" || exit 0

IFS='|' read -r _ app_pid screen_idx window_title <<<"$window_row"
[[ "$app_pid" =~ ^[0-9]+$ ]] || exit 0
[[ "$screen_idx" =~ ^[0-9]+$ ]] || screen_idx=0

MODE="$mode" PID="$app_pid" TITLE="$window_title" WINDOW_ID="$window_id" \
	SCREEN_IDX="$screen_idx" BOTTOM_INSET="$(reserved_bottom_inset)" \
	osascript -l JavaScript <<'JXA'
ObjC.import('stdlib');
ObjC.import('Foundation');
ObjC.import('AppKit');

const SIZE_STAGES = [0.40, 0.60, 0.75, 1];
const ASPECT_RATIO = 16 / 9;

function run() {
  const mode = $.getenv('MODE');
  const pid = parseInt($.getenv('PID'), 10);
  const windowId = $.getenv('WINDOW_ID');
  const wantTitle = $.getenv('TITLE');
  const screenIdx = parseInt($.getenv('SCREEN_IDX'), 10);
  const bottomInset = parseInt($.getenv('BOTTOM_INSET'), 10) || 0;
  const tag = 'win ' + windowId + ' pid ' + pid + ': ';

  // AeroSpace's %{monitor-appkit-nsscreen-screens-id} is a 1-based index into
  // NSScreen.screens. Out of range means the monitor could not be resolved:
  // fall back to the screen holding keyboard focus.
  const screens = $.NSScreen.screens;
  const screen = (screenIdx >= 1 && screenIdx <= screens.count)
    ? screens.objectAtIndex(screenIdx - 1)
    : $.NSScreen.mainScreen;

  // visibleFrame excludes menu bar and Dock but not sketchybar, which is a
  // borderless overlay AppKit never subtracts. Reserve the same band that
  // [gaps] outer.bottom reserves for tiled windows.
  // AppKit measures from the bottom-left of the primary screen, the
  // Accessibility API from the top-left, so Y is flipped against the primary.
  const vf = screen.visibleFrame;
  const primaryH = screens.objectAtIndex(0).frame.size.height;
  const usableW = vf.size.width;
  const usableH = Math.max(vf.size.height - bottomInset, 1);
  const originX = vf.origin.x;
  const originY = primaryH - (vf.origin.y + vf.size.height);

  const proc = Application('System Events').applicationProcesses
    .whose({ unixId: pid })[0];

  // A window AeroSpace has just detected may not be in the AX tree yet.
  let wins = [];
  for (let attempt = 0; attempt < 20; attempt++) {
    try { wins = proc.windows(); } catch (e) { wins = []; }
    if (wins.length) break;
    $.NSThread.sleepForTimeInterval(0.05);
  }
  if (!wins.length) { console.log(tag + 'no AX windows'); return; }

  // Title identifies the exact window when it is unambiguous. Dialogs often
  // have no AXTitle and apps open duplicate titles, so fall back to frontmost.
  let win = null;
  if (wantTitle) {
    const matches = wins.filter(function (w) {
      try { return w.title() === wantTitle; } catch (e) { return false; }
    });
    if (matches.length === 1) win = matches[0];
  }
  if (!win) win = wins[0];

  let size;
  try {
    size = win.size();
  } catch (e) {
    console.log(tag + 'size read failed: ' + e.message);
    return;
  }

  if (mode === 'cycle') {
    let boxW, boxH;
    if (usableW / usableH > ASPECT_RATIO) {
      boxH = usableH;
      boxW = boxH * ASPECT_RATIO;
    } else {
      boxW = usableW;
      boxH = boxW / ASPECT_RATIO;
    }

    // The stage is read back off the window itself rather than a cache file:
    // window ids are recycled, so keyed state resumes mid-cycle on a fresh
    // window. Nearest current height wins, then advance one stage.
    const heights = SIZE_STAGES.map(function (s) { return Math.round(boxH * s); });
    let nearest = 0;
    let bestDelta = Infinity;
    heights.forEach(function (h, i) {
      const delta = Math.abs(h - size[1]);
      if (delta < bestDelta) { bestDelta = delta; nearest = i; }
    });
    const next = (nearest + 1) % SIZE_STAGES.length;

    try {
      win.size = [Math.round(boxW * SIZE_STAGES[next]), heights[next]];
      size = win.size();
    } catch (e) {
      console.log(tag + 'resize failed: ' + e.message);
    }
  }

  try {
    win.position = [
      Math.round(originX + (usableW - size[0]) / 2),
      Math.round(originY + (usableH - size[1]) / 2),
    ];
  } catch (e) {
    console.log(tag + 'move failed: ' + e.message);
  }
}
JXA
