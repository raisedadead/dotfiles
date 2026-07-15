#!/usr/bin/env bash
source "$HOME/.config/sketchybar/colors.sh"

sketchybar --remove '/clock.agenda\..*/' 2>/dev/null

events="$(timeout 10 icalBuddy -nc -nrd -eep "notes,url,location,attendees" -iep "title,datetime" -df "" -tf "%H:%M" -b "" -ps " · " -li 8 eventsToday 2>/dev/null | sed 's/  */ /g')"

i=0
if [ -n "$events" ]; then
	while IFS= read -r line; do
		[ -z "$line" ] && continue
		sketchybar --add item "clock.agenda.$i" popup.clock \
			--set "clock.agenda.$i" \
			icon= icon.color="$PEACH" icon.font="$ICON_FONT:Regular:11.0" \
			icon.padding_left=10 icon.padding_right=6 \
			label="$line" label.font="$FONT:Regular:12.0" label.color="$TEXT" \
			label.max_chars=34 label.padding_right=12 \
			background.drawing=off
		i=$((i + 1))
	done <<<"$events"
fi

if [ "$i" -eq 0 ]; then
	sketchybar --add item clock.agenda.0 popup.clock \
		--set clock.agenda.0 \
		icon= icon.color="$OVERLAY0" icon.font="$ICON_FONT:Regular:11.0" \
		icon.padding_left=10 icon.padding_right=6 \
		label="No events today" label.color="$OVERLAY2" label.font="$FONT:Regular:12.0" \
		label.padding_right=12 background.drawing=off
fi

sketchybar --set clock popup.drawing=toggle
