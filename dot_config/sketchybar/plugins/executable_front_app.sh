#!/usr/bin/env bash
source "$HOME/.config/sketchybar/colors.sh"
source "$HOME/.config/sketchybar/icon_map.sh"
source "$HOME/.config/sketchybar/icon_override.sh"

if [ "$SENDER" = "front_app_switched" ]; then
	__icon_map "$INFO"
	__icon_override "$INFO"
	sketchybar --set "$NAME" icon="$icon_result" label="$INFO"
fi
