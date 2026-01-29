#!/usr/bin/env zsh

#-----------------------------------------------------------
#
# @raisedadead's config files
# Copyright: Mrugesh Mohapatra <https://mrugesh.dev>
# License: ISC
#
# File name: cleanup.sh
#
#-----------------------------------------------------------

#-----------------------------
# Cleanup on macOS
#-----------------------------
_mrgsh_cleanup() {
  if [[ "$1" == "--dry-run" ]]; then
    find . \( -name ".DS_Store" -o -name "._*" -o -name ".Spotlight-V100" -o -name ".Trashes" -o -name ".fseventsd" -o -name "Thumbs.db" \) -print
  else
    find . \( -name ".DS_Store" -o -name "._*" -o -name ".Spotlight-V100" -o -name ".Trashes" -o -name ".fseventsd" -o -name "Thumbs.db" \) -prune -exec rm -rf {} + -print
  fi
}

