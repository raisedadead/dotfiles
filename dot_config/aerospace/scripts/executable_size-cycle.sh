#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/aerospace/size-cycle"
mkdir -p "$STATE_DIR"

read -r window_id app_pid < <(/opt/homebrew/bin/aerospace list-windows --focused --format '%{window-id} %{app-pid}' 2>/dev/null) || true
[[ "${window_id:-}" =~ ^[0-9]+$ && "${app_pid:-}" =~ ^[0-9]+$ ]] || exit 0
state_file="$STATE_DIR/$window_id"

stages=(0.40 0.60 0.75 1)
idx=0
[[ -f "$state_file" ]] && idx="$(cat "$state_file")"
[[ "$idx" =~ ^[0-9]+$ ]] && ((idx < ${#stages[@]})) || idx=0
next=$(((idx + 1) % ${#stages[@]}))
printf '%s\n' "$next" >"$state_file"

SCALE="${stages[$idx]}" PID="$app_pid" osascript -l JavaScript <<'JXA'
ObjC.import('stdlib');
ObjC.import('AppKit');
function run() {
  try {
    const pid = parseInt($.getenv('PID'), 10);
    const scale = parseFloat($.getenv('SCALE'));
    const f = $.NSScreen.mainScreen.frame;
    const W = f.size.width, H = f.size.height, ratio = 16 / 9;
    let boxW, boxH;
    if (W / H > ratio) { boxH = H; boxW = H * ratio; } else { boxW = W; boxH = W / ratio; }
    const w = Math.round(boxW * scale), h = Math.round(boxH * scale);
    const x = Math.round((W - w) / 2), y = Math.round((H - h) / 2);
    const win = Application('System Events').applicationProcesses.whose({ unixId: pid })[0].windows[0];
    win.size = [w, h];
    win.position = [x, y];
  } catch (e) {}
}
JXA
