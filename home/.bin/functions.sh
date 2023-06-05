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
if can_haz fzf; then

    #-----------------------------
    # Quick SSH
    #-----------------------------
    # Credits: https://gist.github.com/dohq/1dc702cc0b46eb62884515ea52330d60
    function fzf-ssh() {
        local selected_host=$(grep -h "Host " ~/.ssh/config_* | grep -v '*' | cut -b 6- | fzf --query "$LBUFFER" --prompt="SSH Remote > ")

        if [ -n "$selected_host" ]; then
            BUFFER="ssh ${selected_host}"
            zle accept-line
        fi
        zle reset-prompt
    }

    zle -N fzf-ssh
    bindkey '^s' fzf-ssh
    setopt noflowcontrol

    #-----------------------------
    # Quick lookup (and edit)
    #-----------------------------
    function check_req() {
        $(type bat >/dev/null 2>&1) && $(type fd >/dev/null 2>&1) && $(type fzf >/dev/null 2>&1)
    }
    function preview_bottom_view() {
        if $(check_req); then

            local selected_file=$(
                fd --type f \
                    --hidden \
                    --follow \
                    --exclude .git |
                    fzf --height 80% \
                        --layout reverse \
                        --info inline \
                        --border \
                        --preview "bat --style=numbers --color=always {} | head -500" \
                        --preview-window "down:24:noborder" \
                        --color=dark \
                        --color=fg:-1,bg:-1,hl:#5fff87,fg+:-1,bg+:-1,hl+:#ffaf5f \
                        --color=info:#af87ff,prompt:#5fff87,pointer:#ff87d7,marker:#ff87d7,spinner:#ff87d7 \
                        --prompt="File > " \
                        --query "$LBUFFER"
            )

            if [ -n "$selected_file" ]; then
                BUFFER="vi $selected_file"
                zle accept-line
            fi
            zle reset-prompt

        fi
    }
    function preview_side_view() {
        if $(check_req); then

            local selected_file=$(

                fd --type f \
                    --hidden \
                    --follow \
                    --exclude .git |
                    fzf --preview "bat --style=numbers --color=always {} | head -500" \
                        --color=dark \
                        --color=fg:-1,bg:-1,hl:#5fff87,fg+:-1,bg+:-1,hl+:#ffaf5f \
                        --color=info:#af87ff,prompt:#5fff87,pointer:#ff87d7,marker:#ff87d7,spinner:#ff87d7

            )

            if [ -n "$selected_file" ]; then
                BUFFER="vi $selected_file"
                zle accept-line
            fi
            zle reset-prompt

        fi
    }

    zle -N preview_side_view
    zle -N preview_bottom_view
    bindkey '^P' preview_side_view
    bindkey '^O' preview_bottom_view
    setopt noflowcontrol

    #-----------------------------
    # Quick remove from known_hosts
    #-----------------------------
    function remove_known_hosts() {
        local hostname_entry
        hostname_entry=$(cat ~/.ssh/known_hosts | awk '{print $1}' | fzf --prompt="Hostname Entry > ")

        # Exit if no hostname_entry is selected
        if [[ -z $hostname_entry ]]; then
            return
        fi

        echo "Removing $hostname_entry from known_hosts"
        ssh-keygen -R $hostname_entry
        rm -rf ~/.ssh/known_hosts.old
    }

    alias rkh=remove_known_hosts
    setopt noflowcontrol
fi
