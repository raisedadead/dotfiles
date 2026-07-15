#!/usr/bin/env bash
source "$HOME/.config/sketchybar/colors.sh"

CORES="$(sysctl -n hw.ncpu 2>/dev/null || echo 1)"
CPU="$(ps -A -o %cpu 2>/dev/null | awk -v c="$CORES" 'NR>1{s+=$1} END{printf "%.0f", s/c}')"
[ -z "$CPU" ] && CPU=0

if [ "$CPU" -ge 80 ]; then
	COL="$RED"
elif [ "$CPU" -ge 50 ]; then
	COL="$YELLOW"
else
	COL="$GREEN"
fi

sketchybar --set "$NAME" icon.color="$COL" label="${CPU}%"
