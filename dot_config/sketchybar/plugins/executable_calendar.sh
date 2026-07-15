#!/usr/bin/env bash
source "$HOME/.config/sketchybar/colors.sh"

BIN="$HOME/.config/sketchybar/bin/calendar_events.app/Contents/MacOS/calendar_events"
NEXT=""
[ -x "$BIN" ] && NEXT="$(timeout 8 "$BIN" --next 2>/dev/null | head -1 | cut -c1-30)"
[ -z "$NEXT" ] && NEXT="No events"

sketchybar --set "$NAME" label="$NEXT"
