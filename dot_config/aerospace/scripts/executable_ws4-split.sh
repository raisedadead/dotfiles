#!/usr/bin/env bash
set -u

AEROSPACE=/opt/homebrew/bin/aerospace
WORKSPACE=4
SPARK=com.readdle.SparkDesktop
SPOTIFY=com.spotify.client
WINDOW_LOOKUP_ATTEMPTS=20
WINDOW_LOOKUP_INTERVAL=0.05

config_path() {
  local config
  config="$("$AEROSPACE" config --config-path 2> /dev/null || true)"
  [[ -f "$config" ]] || config="${XDG_CONFIG_HOME:-$HOME/.config}/aerospace/aerospace.toml"
  printf '%s\n' "$config"
}

gap() {
  awk -F'=' -v pat="^$1" '$0 ~ pat { gsub(/[^0-9]/, "", $2); print $2; exit }' "$2"
}

screen_width() {
  SCREEN_IDX="$1" osascript -l JavaScript <<'JXA'
ObjC.import('stdlib');
ObjC.import('AppKit');
function run() {
  const idx = parseInt($.getenv('SCREEN_IDX'), 10);
  const screens = $.NSScreen.screens;
  const screen = (idx >= 1 && idx <= screens.count)
    ? screens.objectAtIndex(idx - 1)
    : $.NSScreen.mainScreen;
  return String(Math.round(screen.visibleFrame.size.width));
}
JXA
}

rows=""
spark=""
spotify=""
screen_idx=""
for _attempt in $(seq 1 "$WINDOW_LOOKUP_ATTEMPTS"); do
  rows="$("$AEROSPACE" list-windows --workspace "$WORKSPACE" \
    --format '%{window-id}|%{app-bundle-id}|%{monitor-appkit-nsscreen-screens-id}' 2> /dev/null || true)"
  spark="$(awk -F'|' -v b="$SPARK" '$2 == b { print $1; exit }' <<< "$rows")"
  spotify="$(awk -F'|' -v b="$SPOTIFY" '$2 == b { print $1; exit }' <<< "$rows")"
  screen_idx="$(awk -F'|' -v b="$SPOTIFY" '$2 == b { print $3; exit }' <<< "$rows")"
  [[ -n "$spark" && -n "$spotify" ]] && break
  sleep "$WINDOW_LOOKUP_INTERVAL"
done

[[ -n "$spark" && -n "$spotify" ]] || exit 0
(($(grep -c . <<< "$rows") == 2)) || exit 0
[[ "$screen_idx" =~ ^[0-9]+$ ]] || screen_idx=0

width="$(screen_width "$screen_idx" 2> /dev/null)"
[[ "$width" =~ ^[0-9]+$ ]] || exit 0

config="$(config_path)"
[[ -f "$config" ]] || exit 0
outer_left="$(gap 'outer\.left' "$config")"
outer_right="$(gap 'outer\.right' "$config")"
inner="$(gap 'inner\.horizontal' "$config")"
for v in "$outer_left" "$outer_right" "$inner"; do
  [[ "$v" =~ ^[0-9]+$ ]] || exit 0
done

usable=$((width - outer_left - outer_right - inner))
((usable > 0)) || exit 0

"$AEROSPACE" layout --workspace "$WORKSPACE" --root h_tiles > /dev/null 2>&1
"$AEROSPACE" move left --window-id "$spark" \
  --boundaries workspace --boundaries-action stop > /dev/null 2>&1
"$AEROSPACE" resize width $((usable / 3)) --window-id "$spotify" > /dev/null 2>&1
