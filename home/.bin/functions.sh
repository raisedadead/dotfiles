#!/usr/bin/env

#-----------------------------------------------------------
#
# @raisedadead's config files
# https://get.ms/dotfiles
#
# Copyright: Mrugesh Mohapatra <https://mrugesh.dev>
# License: ISC
#
# File name: functions.sh
#
#-----------------------------------------------------------

#-----------------------------
# Commit in the past
#-----------------------------
function rollback-no-of-days() {
    if [ "$1" != "" ]; then
        COMMIT_TARGET_DATE="undefined"
        [ -f ~/.bin/utils.sh ] && source ~/.bin/utils.sh && TARGET=$(_get_system)
        case "$TARGET" in
        macos*)
            COMMIT_TARGET_DATE=$(date -v-$1d)
            ;;
        linux*)
            COMMIT_TARGET_DATE=$(date --date="$1 days ago")
            ;;
        *) ;;

        esac
        if [ "$COMMIT_TARGET_DATE" != "undefined" ]; then
            GIT_COMMITTER_DATE="$COMMIT_TARGET_DATE" git commit --amend --no-edit --date "$COMMIT_TARGET_DATE"
        else
            echo "An error occured in the custom script, or not implemented for your OS"
        fi
    else
        echo "Please pass an argument as a number (as in days ago)."
    fi
}

#-----------------------------
# Precmd
#-----------------------------
precmd() {print -Pn "\e]0;%~\a"}

