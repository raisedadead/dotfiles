#!/usr/bin/env bash
source "$HOME/.config/sketchybar/colors.sh"

if [ "$MODE" = "service" ]; then
	sketchybar --set "$NAME" drawing=on
else
	sketchybar --set "$NAME" drawing=off
fi
