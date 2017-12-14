#!/bin/bash

# Detect OS and return installation type

_get_system()
{
    DOT_TARGET="undefined"
    case "$OSTYPE" in
        darwin*)
		DOT_TARGET="macos"
		;;
	solaris*|bsd*|linux*)
		DOT_TARGET="linux"
		;;
        msys*|cygwin*)
		DOT_TARGET="windows"
		;;
        *)    
		DOT_TARGET="unknown"
		;;
    esac
    echo "$DOT_TARGET"
}

