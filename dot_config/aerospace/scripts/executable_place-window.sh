#!/usr/bin/env bash
set -euo pipefail

AEROSPACE=/opt/homebrew/bin/aerospace
WINDOW_LOOKUP_ATTEMPTS=20
WINDOW_LOOKUP_INTERVAL=0.05

usage() {
	printf 'usage: place-window.sh <center|cycle>\n' >&2
	exit 2
}

mode="${1:-center}"
case "$mode" in
center | cycle) ;;
*) usage ;;
esac

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

window_id="$(resolve_window_id)" || exit 0
window_row="$(resolve_window_row "$window_id")" || exit 0

IFS='|' read -r _ app_pid screen_idx window_title <<<"$window_row"
[[ "$app_pid" =~ ^[0-9]+$ ]] || exit 0
[[ "$screen_idx" =~ ^[0-9]+$ ]] || screen_idx=0

MODE="$mode" PID="$app_pid" TITLE="$window_title" SCREEN_IDX="$screen_idx" \
	osascript -l JavaScript <<'JXA'
ObjC.import('stdlib');
ObjC.import('Foundation');
ObjC.import('AppKit');

const SIZE_STAGES = [0.40, 0.60, 0.75, 1];
const ASPECT_RATIO = 16 / 9;

function run() {
  const mode = $.getenv('MODE');
  const pid = parseInt($.getenv('PID'), 10);
  const wantTitle = $.getenv('TITLE');
  const screenIdx = parseInt($.getenv('SCREEN_IDX'), 10);

  // AeroSpace's %{monitor-appkit-nsscreen-screens-id} is a 1-based index into
  // NSScreen.screens. Out of range means the monitor could not be resolved:
  // fall back to the screen holding keyboard focus.
  const screens = $.NSScreen.screens;
  const screen = (screenIdx >= 1 && screenIdx <= screens.count)
    ? screens.objectAtIndex(screenIdx - 1)
    : $.NSScreen.mainScreen;

  // visibleFrame excludes the menu bar and Dock. sketchybar is deliberately
  // NOT reserved — centre means screen centre.
  // AppKit measures from the bottom-left of the primary screen, the
  // Accessibility API from the top-left, so Y is flipped against the primary.
  const vf = screen.visibleFrame;
  const primaryH = screens.objectAtIndex(0).frame.size.height;
  const originX = vf.origin.x;
  const originY = primaryH - (vf.origin.y + vf.size.height);

  const centreFor = function (w, h) {
    return [
      Math.round(originX + (vf.size.width - w) / 2),
      Math.round(originY + (vf.size.height - h) / 2),
    ];
  };

  const proc = Application('System Events').applicationProcesses
    .whose({ unixId: pid })[0];

  // A window AeroSpace has just detected may not be in the AX tree yet.
  let wins = [];
  for (let attempt = 0; attempt < 20; attempt++) {
    try { wins = proc.windows(); } catch (e) { wins = []; }
    if (wins.length) break;
    $.NSThread.sleepForTimeInterval(0.05);
  }
  if (!wins.length) return;

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
    return;
  }

  if (mode !== 'cycle') {
    try { win.position = centreFor(size[0], size[1]); } catch (e) { }
    return;
  }

  let boxW, boxH;
  if (vf.size.width / vf.size.height > ASPECT_RATIO) {
    boxH = vf.size.height;
    boxW = boxH * ASPECT_RATIO;
  } else {
    boxW = vf.size.width;
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
  const target = [Math.round(boxW * SIZE_STAGES[next]), heights[next]];

  // Position first, then size: growing in place reads as one motion, whereas
  // resizing and then sliding to centre is two visible jumps.
  try { win.position = centreFor(target[0], target[1]); } catch (e) { return; }
  try { win.size = target; } catch (e) { return; }

  // Apps with a fixed or minimum size ignore the requested rect, which leaves
  // the window off-centre. Only then is a second move worth it.
  try {
    const actual = win.size();
    if (actual[0] !== target[0] || actual[1] !== target[1]) {
      win.position = centreFor(actual[0], actual[1]);
    }
  } catch (e) { }
}
JXA
