#!/usr/bin/env bash

function __nerd_icon() {
	case "$1" in
	clock) icon_result="$(printf '\357\200\227')" ;;
	calendar) icon_result="$(printf '\357\201\263')" ;;
	weather) icon_result="$(printf '\357\206\205')" ;;
	cpu) icon_result="$(printf '\357\213\233')" ;;
	net) icon_result="$(printf '\357\204\262')" ;;
	service) icon_result="$(printf '\357\200\223')" ;;
	*) icon_result="$(printf '\357\201\251')" ;;
	esac
}
