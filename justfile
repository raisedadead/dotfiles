# Dotfiles Management with Just
# Run `home` or `home help` for available commands

set shell := ["bash", "-cu"]

# Configuration
public := "~/.dotfiles"
private := "~/.dotfiles-private"

# Default recipe - show help
default: help

# Show available commands
help:
    #!/usr/bin/env bash
    B=$'\e[1m'; D=$'\e[0;90m'; R=$'\e[0m'
    echo ""
    printf "  ${B}home check${R}               ${D}status + what to do next${R}\n"
    printf "  ${B}home apply${R}               ${D}apply both repos to ~${R}\n"
    printf "  ${B}home pull${R}                ${D}pull + apply both repos${R}\n"
    printf "  ${B}home push${R}                ${D}push both repos${R}\n"
    printf "  ${B}home status${R}              ${D}git status both repos${R}\n"
    printf "  ${B}home diff${R}                ${D}diff both repos${R}\n"
    printf "  ${B}home managed${R}             ${D}list all managed files${R}\n"
    printf "  ${B}home verify${R}              ${D}verify sync state${R}\n"
    printf "  ${B}home init${R}                ${D}first-time setup${R}\n"
    echo ""
    printf "  ${D}Everything else passes through to chezmoi:${R}\n"
    printf "  ${D}home re-add, home edit, home doctor, etc.${R}\n"
    echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Setup
# ─────────────────────────────────────────────────────────────────────────────

# First-time setup: clone private repo and apply both
[no-exit-message]
init:
    #!/usr/bin/env bash
    set -euo pipefail
    D=$'\e[0;90m'; G=$'\e[0;32m'; Y=$'\e[0;33m'; B=$'\e[1m'; R=$'\e[0m'
    p() { printf "${D}dotfiles ·${R} %s\n" "$1"; }
    ok() { printf "${G}dotfiles ·${R} %s\n" "$1"; }
    if [ ! -d {{ private }} ]; then
        p "cloning private repo..."
        git clone git@github.com:raisedadead/dotfiles-private.git {{ private }} || {
            printf "${Y}dotfiles ·${R} clone failed — is SSH configured?\n"
            printf "           run ${B}home init${R} after setting up SSH\n"
            exit 1
        }
    else
        p "private repo exists"
    fi
    p "applying public..."
    chezmoi apply
    p "applying private..."
    chezmoi --source {{ private }} apply
    ok "done"

# ─────────────────────────────────────────────────────────────────────────────
# Apply
# ─────────────────────────────────────────────────────────────────────────────

# Apply both public and private dotfiles
apply: apply-public apply-private

# Apply public dotfiles only
[no-exit-message]
apply-public:
    #!/usr/bin/env bash
    D=$'\e[0;90m'; G=$'\e[0;32m'; R=$'\e[0m'
    printf "${D}dotfiles ·${R} applying public...\n"
    chezmoi apply
    printf "${G}dotfiles ·${R} public applied\n"

# Apply private dotfiles only
[no-exit-message]
apply-private:
    #!/usr/bin/env bash
    set -euo pipefail
    D=$'\e[0;90m'; G=$'\e[0;32m'; Y=$'\e[0;33m'; R=$'\e[0m'
    if [ ! -d {{ private }} ]; then
        printf "${Y}dotfiles ·${R} private repo not found — run home init\n"
        exit 1
    fi
    printf "${D}dotfiles ·${R} applying private...\n"
    chezmoi --source {{ private }} apply
    printf "${G}dotfiles ·${R} private applied\n"

# ─────────────────────────────────────────────────────────────────────────────
# Sync
# ─────────────────────────────────────────────────────────────────────────────

# Pull latest and apply both repos
[no-exit-message]
pull:
    #!/usr/bin/env bash
    set -euo pipefail
    D=$'\e[0;90m'; G=$'\e[0;32m'; R=$'\e[0m'
    printf "${D}dotfiles ·${R} pulling public...\n"
    chezmoi update
    printf "${G}dotfiles ·${R} public updated\n"
    if [ -d {{ private }} ]; then
        printf "${D}dotfiles ·${R} pulling private...\n"
        git -C {{ private }} pull --rebase
        chezmoi --source {{ private }} apply
        printf "${G}dotfiles ·${R} private updated\n"
    fi

# Push both repos
[no-exit-message]
push:
    #!/usr/bin/env bash
    set -euo pipefail
    D=$'\e[0;90m'; G=$'\e[0;32m'; Y=$'\e[0;33m'; R=$'\e[0m'
    export DOTFILES_PUSH=1
    PUB_BRANCH=$(git -C {{ public }} branch --show-current)
    printf "${D}dotfiles ·${R} pushing public (%s)...\n" "$PUB_BRANCH"
    git -C {{ public }} push origin "$PUB_BRANCH"
    printf "${G}dotfiles ·${R} public pushed\n"
    if [ -d {{ private }} ]; then
        PRIV_BRANCH=$(git -C {{ private }} branch --show-current)
        printf "${D}dotfiles ·${R} pushing private (%s)...\n" "$PRIV_BRANCH"
        git -C {{ private }} push origin "$PRIV_BRANCH"
        printf "${G}dotfiles ·${R} private pushed\n"
    fi

# Show git status of both repos
[no-exit-message]
status:
    #!/usr/bin/env bash
    D=$'\e[0;90m'; B=$'\e[1m'; R=$'\e[0m'
    printf "${D}dotfiles ·${R} ${B}public${R}\n"
    git -C {{ public }} status --short
    if [ -d {{ private }} ]; then
        echo ""
        printf "${D}dotfiles ·${R} ${B}private${R}\n"
        git -C {{ private }} status --short
    else
        printf "\n${D}dotfiles · private not cloned${R}\n"
    fi

# ─────────────────────────────────────────────────────────────────────────────
# Info
# ─────────────────────────────────────────────────────────────────────────────

# Show pending changes for both repos
[no-exit-message]
diff:
    #!/usr/bin/env bash
    D=$'\e[0;90m'; B=$'\e[1m'; R=$'\e[0m'
    printf "${D}dotfiles ·${R} ${B}public${R}\n"
    chezmoi diff || true
    if [ -d {{ private }} ]; then
        echo ""
        printf "${D}dotfiles ·${R} ${B}private${R}\n"
        chezmoi --source {{ private }} diff || true
    fi

# List all managed files
[no-exit-message]
managed:
    #!/usr/bin/env bash
    D=$'\e[0;90m'; B=$'\e[1m'; R=$'\e[0m'
    PUB_N=$(chezmoi managed | wc -l | tr -d ' ')
    printf "${D}dotfiles ·${R} ${B}public${R} ${D}(%s files)${R}\n" "$PUB_N"
    chezmoi managed
    if [ -d {{ private }} ]; then
        PRIV_N=$(chezmoi --source {{ private }} managed | wc -l | tr -d ' ')
        echo ""
        printf "${D}dotfiles ·${R} ${B}private${R} ${D}(%s files)${R}\n" "$PRIV_N"
        chezmoi --source {{ private }} managed
    fi

# Verify all managed files are in sync
[no-exit-message]
verify:
    #!/usr/bin/env bash
    D=$'\e[0;90m'; G=$'\e[0;32m'; Y=$'\e[0;33m'; B=$'\e[1m'; R=$'\e[0m'
    printf "${D}dotfiles ·${R} ${B}public${R}  "
    if chezmoi verify 2>/dev/null; then
        printf "${G}in sync${R}\n"
    else
        printf "${Y}drift detected${R} — run ${B}home diff${R}\n"
    fi
    if [ -d {{ private }} ]; then
        printf "${D}dotfiles ·${R} ${B}private${R} "
        if chezmoi --source {{ private }} verify 2>/dev/null; then
            printf "${G}in sync${R}\n"
        else
            printf "${Y}drift detected${R} — run ${B}home diff${R}\n"
        fi
    fi

# Actionable health check — shows status + what to do next
[no-exit-message]
check:
    #!/usr/bin/env bash
    set -uo pipefail
    DIM=$'\e[0;90m'; GRN=$'\e[0;32m'; RED=$'\e[0;31m'; YLW=$'\e[0;33m'
    CYN=$'\e[0;36m'; BLD=$'\e[1m'; RST=$'\e[0m'
    PUB="$HOME/.dotfiles"; PRIV="$HOME/.dotfiles-private"
    PUB_N=$(chezmoi managed 2>/dev/null | wc -l | tr -d ' ')
    PRIV_N=$(chezmoi --source "$PRIV" managed 2>/dev/null | wc -l | tr -d ' ')
    printf "${BLD}dotfiles${RST} ${DIM}· %s public · %s private${RST}\n\n" "$PUB_N" "$PRIV_N"
    # Fetch for accurate ahead/behind
    git -C "$PUB" fetch --quiet 2>/dev/null &
    [ -d "$PRIV" ] && git -C "$PRIV" fetch --quiet 2>/dev/null &
    wait
    # Accumulate actions in workflow order
    ACT_PULL=""; ACT_COMMIT=""; ACT_APPLY=""; ACT_PUSH=""
    HAS_ISSUES=0
    for REPO in public private; do
        if [ "$REPO" = "public" ]; then
            DIR="$PUB"; CM_SRC=""; CD="cd ~/.dotfiles"; APPLY="home apply"
        else
            DIR="$PRIV"; CM_SRC="--source $PRIV"; CD="cd ~/.dotfiles-private"; APPLY="home apply-private"
            if [ ! -d "$DIR" ]; then
                printf "  ${DIM}%-10s not cloned${RST}\n" "$REPO"
                continue
            fi
        fi
        # Ahead/behind
        AHEAD=0; BEHIND=0
        BR=$(git -C "$DIR" branch --show-current 2>/dev/null)
        if git -C "$DIR" rev-parse --verify "origin/$BR" &>/dev/null; then
            read -r BEHIND AHEAD < <(git -C "$DIR" rev-list --left-right --count "origin/$BR...HEAD" 2>/dev/null)
        fi
        # Dirty working tree
        DIRTY=$(git -C "$DIR" status --porcelain 2>/dev/null)
        DIRTY_N=0; [ -n "$DIRTY" ] && DIRTY_N=$(echo "$DIRTY" | wc -l | tr -d ' ')
        # Unapplied source → target
        UNAPPLIED=$(chezmoi $CM_SRC diff --no-pager 2>&1 | grep -c '^diff' || true)
        # Format status line
        S=""
        [ "$BEHIND" -gt 0 ]    && S="${S} ${CYN}${BEHIND}↓${RST}"
        [ "$AHEAD" -gt 0 ]     && S="${S} ${YLW}${AHEAD}↑${RST}"
        [ "$DIRTY_N" -gt 0 ]   && S="${S} ${RED}${DIRTY_N} dirty${RST}"
        [ "$UNAPPLIED" -gt 0 ] && S="${S} ${YLW}${UNAPPLIED} to apply${RST}"
        if [ -z "$S" ]; then
            printf "  %-10s ${GRN}✓${RST}\n" "$REPO"
        else
            HAS_ISSUES=1
            printf "  %-10s%s\n" "$REPO" "$S"
            if [ -n "$DIRTY" ]; then
                echo "$DIRTY" | while IFS= read -r l; do
                    printf "  ${DIM}           %s${RST}\n" "$l"
                done
            fi
        fi
        # Collect actions in workflow order (pad command to 26 chars)
        pad() { local n=$((26 - ${#1})); printf '%*s' "$n" ''; }
        [ "$BEHIND" -gt 0 ]    && ACT_PULL="  ${BLD}home pull${RST}$(pad 'home pull')${DIM}pull from origin${RST}\n"
        [ "$DIRTY_N" -gt 0 ]   && ACT_COMMIT="${ACT_COMMIT}  ${BLD}${CD}${RST}$(pad "$CD")${DIM}commit ${DIRTY_N} files${RST}\n"
        [ "$UNAPPLIED" -gt 0 ] && ACT_APPLY="${ACT_APPLY}  ${BLD}${APPLY}${RST}$(pad "$APPLY")${DIM}apply ${UNAPPLIED} files to ~${RST}\n"
        [ "$AHEAD" -gt 0 ]     && ACT_PUSH="  ${BLD}home push${RST}$(pad 'home push')${DIM}push to origin${RST}\n"
    done
    # Print suggested actions
    ACTS="${ACT_PULL}${ACT_COMMIT}${ACT_APPLY}${ACT_PUSH}"
    if [ -n "$ACTS" ]; then
        printf "\n${DIM}next →${RST}\n"
        printf "%b" "$ACTS"
    elif [ "$HAS_ISSUES" -eq 0 ]; then
        printf "\n${GRN}all clear${RST}\n"
    fi
