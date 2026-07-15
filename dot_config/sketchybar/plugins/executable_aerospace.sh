#!/usr/bin/env bash
source "$HOME/.config/sketchybar/colors.sh"
source "$HOME/.config/sketchybar/icon_map.sh"
source "$HOME/.config/sketchybar/icon_override.sh"

SID="${1:-${NAME#space.}}"
FOCUSED="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}"

apps="$(aerospace list-windows --workspace "$SID" --format '%{app-name}' 2>/dev/null)"
strip=""
n=0
while IFS= read -r app; do
	[ -z "$app" ] && continue
	__icon_map "$app"
	__icon_override "$app"
	strip+="${icon_result} "
	n=$((n + 1))
done <<<"$apps"

if [ "$SID" = "$FOCUSED" ]; then
	sketchybar --set "$NAME" drawing=on background.drawing=on icon.color="$CRUST" label="$strip" label.color="$CRUST"
else
	item_draw=on
	if [[ ("$SID" = 5 || "$SID" = 6) && "$n" -eq 0 ]]; then item_draw=off; fi
	sketchybar --set "$NAME" drawing="$item_draw" background.drawing=off icon.color="$OVERLAY2" label="$strip" label.color="$OVERLAY2"
fi
