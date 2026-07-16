#!/usr/bin/env bash
source "$HOME/.config/sketchybar/colors.sh"
source "$HOME/.config/sketchybar/icons.sh"
__nerd_icon net
NET_ICON="$icon_result"

TS="$(command -v tailscale || echo /Applications/Tailscale.app/Contents/MacOS/Tailscale)"
TS_JSON="$("$TS" status --json 2>/dev/null)"
IFS=$'\t' read -r STATE EXIT_NODE_FQDN <<<"$(jq -r '[(.BackendState // "Unknown"), (first((.Peer // {})[] | select(.ExitNode == true) | .DNSName) // "")] | @tsv' <<<"$TS_JSON" 2>/dev/null)"
EXIT_NODE="${EXIT_NODE_FQDN%%.*}"

case "$STATE" in
Running)
	if [ -n "$EXIT_NODE" ]; then
		sketchybar --set "$NAME" icon="$NET_ICON" icon.color="$MAUVE" label="$EXIT_NODE"
	else
		sketchybar --set "$NAME" icon="$NET_ICON" icon.color="$GREEN" label="on"
	fi
	;;
Stopped | NeedsLogin | NoState | "")
	sketchybar --set "$NAME" icon="$NET_ICON" icon.color="$OVERLAY0" label="off"
	;;
*)
	sketchybar --set "$NAME" icon="$NET_ICON" icon.color="$YELLOW" label="$STATE"
	;;
esac
