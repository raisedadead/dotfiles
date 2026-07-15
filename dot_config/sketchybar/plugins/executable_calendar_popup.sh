#!/usr/bin/env bash
source "$HOME/.config/sketchybar/colors.sh"

BIN="$HOME/.config/sketchybar/bin/calendar_events"

sketchybar --remove '/clock.agenda\..*/' 2>/dev/null

add_row() {
	sketchybar --add item "clock.agenda.$1" popup.clock \
		--set "clock.agenda.$1" \
		icon="$ICON_CALENDAR" icon.color="$2" icon.font="$ICON_FONT:Regular:11.0" \
		icon.padding_left=10 icon.padding_right=6 \
		label="$3" label.font="$FONT:Regular:12.0" label.color="$4" \
		label.max_chars=36 label.padding_right=12 \
		background.drawing=off
}

i=0
if [ -x "$BIN" ]; then
	while IFS= read -r line; do
		[ -z "$line" ] && continue
		add_row "$i" "$PEACH" "$line" "$TEXT"
		i=$((i + 1))
	done < <(timeout 8 "$BIN" 2>/dev/null)
fi

[ "$i" -eq 0 ] && add_row 0 "$OVERLAY0" "No events today" "$OVERLAY2"

sketchybar --set clock popup.drawing=toggle
