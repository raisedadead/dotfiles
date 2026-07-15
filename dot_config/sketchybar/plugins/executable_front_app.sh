#!/usr/bin/env bash
source "$HOME/.config/sketchybar/colors.sh"
source "$HOME/.config/sketchybar/icon_map.sh"

if [ "$SENDER" = "front_app_switched" ]; then
	__icon_map "$INFO"
	sketchybar --set "$NAME" icon="$icon_result" label="$INFO"
fi
