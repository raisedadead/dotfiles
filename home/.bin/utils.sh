#!/bin/bash

#-----------------------------------------------------------
#
# @raisedadead's config files
# Copyright: Mrugesh Mohapatra <https://mrugesh.dev>
# License: ISC
#
# File name: utils.sh
#
#-----------------------------------------------------------

# Detect OS and return installation type
function _get_system() {
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
