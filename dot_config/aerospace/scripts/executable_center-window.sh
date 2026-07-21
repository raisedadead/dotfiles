#!/usr/bin/env bash
set -euo pipefail
sleep 0.15
pid="$(/opt/homebrew/bin/aerospace list-windows --focused --format '%{app-pid}' 2>/dev/null || true)"
[[ "$pid" =~ ^[0-9]+$ ]] || exit 0
PID="$pid" osascript -l JavaScript <<'JXA'
ObjC.import('stdlib');
ObjC.import('AppKit');
try {
  const pid = parseInt($.getenv('PID'), 10);
  const scr = $.NSScreen.mainScreen.frame;
  const W = scr.size.width, H = scr.size.height;
  const win = Application('System Events').applicationProcesses.whose({ unixId: pid })[0].windows[0];
  const sz = win.size();
  win.position = [Math.round((W - sz[0]) / 2), Math.round((H - sz[1]) / 2)];
} catch (e) {}
JXA
