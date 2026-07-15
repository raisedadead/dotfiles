#!/usr/bin/env bash
source "$HOME/.config/sketchybar/colors.sh"

SID="${1:-${NAME#space.}}"
FOCUSED="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}"

if [ "$SID" = "$FOCUSED" ]; then
	sketchybar --set "$NAME" background.drawing=on label.color="$CRUST"
else
	sketchybar --set "$NAME" background.drawing=off label.color="$OVERLAY2"
fi
