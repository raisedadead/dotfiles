#!/usr/bin/env bash
sleep 0.15
osascript -l JavaScript <<'JXA'
ObjC.import('AppKit');
try {
  const scr = $.NSScreen.mainScreen.frame;
  const W = scr.size.width, H = scr.size.height;
  const se = Application('System Events');
  const proc = se.applicationProcesses.whose({ frontmost: true })[0];
  const win = proc.windows[0];
  const sz = win.size();
  win.position = [Math.round((W - sz[0]) / 2), Math.round((H - sz[1]) / 2)];
} catch (e) {}
JXA
