#!/usr/bin/env bash
source "$HOME/.config/sketchybar/colors.sh"

TS="$(command -v tailscale || echo /Applications/Tailscale.app/Contents/MacOS/Tailscale)"
STATE="$("$TS" status --json 2>/dev/null | jq -r '.BackendState // "Unknown"' 2>/dev/null)"

case "$STATE" in
Running)
	EXIT_NODE="$("$TS" status --json 2>/dev/null |
		jq -r 'first((.Peer // {})[] | select(.ExitNode == true) | .DNSName) // empty' 2>/dev/null |
		cut -d. -f1)"
	if [ -n "$EXIT_NODE" ]; then
		sketchybar --set "$NAME" icon= icon.color="$MAUVE" label="$EXIT_NODE"
	else
		sketchybar --set "$NAME" icon= icon.color="$GREEN" label="on"
	fi
	;;
Stopped | NeedsLogin | NoState | "")
	sketchybar --set "$NAME" icon= icon.color="$OVERLAY0" label="off"
	;;
*)
	sketchybar --set "$NAME" icon= icon.color="$YELLOW" label="$STATE"
	;;
esac
