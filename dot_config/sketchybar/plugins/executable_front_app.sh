#!/usr/bin/env bash
source "$HOME/.config/sketchybar/colors.sh"

if [ "$SENDER" = "front_app_switched" ]; then
	sketchybar --set "$NAME" label="$INFO"
fi
