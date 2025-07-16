#!/usr/bin/env zsh

# detect OS and return installation type
function _mrgsh_get_system() {
    DOT_TARGET="undefined"
    case "$OSTYPE" in
    darwin*)
        DOT_TARGET="macos"
        ;;
    solaris* | bsd* | linux*)
        DOT_TARGET="linux"
        ;;
    msys* | cygwin*)
        DOT_TARGET="windows"
        ;;
    *)
        DOT_TARGET="unknown"
        ;;
    esac
    echo "$DOT_TARGET"
}

# check tool availability
function _mrgsh_check_tools() {
	local tools=("$@")
	for tool in "${tools[@]}"; do
		if ! command -v "$tool" &>/dev/null; then
			echo "Error: Required tool '$tool' is not installed." >&2
			return 1
		fi
	done
}
