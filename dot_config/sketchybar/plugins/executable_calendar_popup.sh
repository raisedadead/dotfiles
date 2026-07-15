#!/usr/bin/env bash
source "$HOME/.config/sketchybar/colors.sh"

sketchybar --remove '/clock.agenda\..*/' 2>/dev/null

raw="$(timeout 10 icalBuddy -nc -nrd -eep "notes,url,location,attendees" -iep "datetime,title" -po "datetime,title" -df "" -tf "%H:%M" -b "" -li 8 eventsToday 2>/dev/null)"

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
dt=""
while IFS= read -r line; do
	trimmed="${line#"${line%%[![:space:]]*}"}"
	[ -z "$trimmed" ] && continue
	case "$line" in
	[[:space:]]*)
		add_row "$i" "$PEACH" "${dt:+$dt  }$trimmed" "$TEXT"
		i=$((i + 1))
		;;
	*)
		dt="${trimmed%% *}"
		;;
	esac
done <<<"$raw"

[ "$i" -eq 0 ] && add_row 0 "$OVERLAY0" "No events today" "$OVERLAY2"

sketchybar --set clock popup.drawing=toggle
