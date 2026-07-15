#!/usr/bin/env bash
source "$HOME/.config/sketchybar/colors.sh"

READING="$(curl -sf --max-time 5 'https://wttr.in/?format=%t' 2>/dev/null | tr -d '+' | xargs)"

if [ -z "$READING" ]; then
	sketchybar --set "$NAME" label="--"
else
	sketchybar --set "$NAME" label="$READING"
fi
