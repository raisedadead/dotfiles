#!/usr/bin/env bash
source "$HOME/.config/sketchybar/colors.sh"

NEXT=""
if command -v icalBuddy >/dev/null 2>&1; then
	NEXT="$(timeout 10 icalBuddy \
		-eep "notes,url,location,attendees" \
		-iep "datetime,title" \
		-df "" -tf "%H:%M" \
		-b "" -nc -nrd \
		-li 1 \
		eventsToday+1 2>/dev/null | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-30 | xargs)"
fi

[ -z "$NEXT" ] && NEXT="No events"

sketchybar --set "$NAME" label="$NEXT"
