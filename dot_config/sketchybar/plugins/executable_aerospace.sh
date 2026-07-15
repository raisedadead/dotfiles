#!/usr/bin/env bash
source "$HOME/.config/sketchybar/colors.sh"
source "$HOME/.config/sketchybar/icon_map.sh"

SID="${1:-${NAME#space.}}"
FOCUSED="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}"

apps="$(aerospace list-windows --workspace "$SID" --format '%{app-name}' 2>/dev/null)"
strip=""
while IFS= read -r app; do
	[ -z "$app" ] && continue
	__icon_map "$app"
	strip+="${icon_result} "
done <<<"$apps"

if [ "$SID" = "$FOCUSED" ]; then
	sketchybar --set "$NAME" background.drawing=on icon.color="$CRUST" label="$strip" label.color="$CRUST"
else
	sketchybar --set "$NAME" background.drawing=off icon.color="$OVERLAY2" label="$strip" label.color="$OVERLAY2"
fi
