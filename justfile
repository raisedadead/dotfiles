# Dotfiles Management with Just
# Run `just` or `just help` for available recipes

set shell := ["bash", "-cu"]

# Configuration
public := "~/.dotfiles"
private := "~/.dotfiles-private"

# Default recipe - show help
default: help

# Show available recipes
help:
    @echo "Dotfiles Management:"
    @echo ""
    @echo "  Setup:"
    @echo "    just init                - First-time setup (clone private, apply both)"
    @echo ""
    @echo "  Daily:"
    @echo "    just apply               - Apply both public and private dotfiles"
    @echo "    just apply-public        - Apply public dotfiles only"
    @echo "    just apply-private       - Apply private dotfiles only"
    @echo "    just edit FILE           - Edit a managed file (opens in \$EDITOR)"
    @echo "    just add FILE            - Add a file to public dotfiles"
    @echo "    just add-private FILE    - Add a file to private dotfiles"
    @echo "    just re-add FILE         - Re-add a changed file to public dotfiles"
    @echo ""
    @echo "  Sync:"
    @echo "    just pull                - Pull and apply both repos"
    @echo "    just push                - Push both repos"
    @echo "    just status              - Show status of both repos"
    @echo ""
    @echo "  Info:"
    @echo "    just diff                - Show pending changes (both repos)"
    @echo "    just managed             - List all managed files"
    @echo "    just doctor              - Run chezmoi doctor"
    @echo "    just verify              - Verify all managed files are in sync"

# ─────────────────────────────────────────────────────────────────────────────
# Setup
# ─────────────────────────────────────────────────────────────────────────────

# First-time setup: clone private repo and apply both
[no-exit-message]
init:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -d {{ private }} ]; then
        echo "Cloning private dotfiles..."
        git clone git@github.com:raisedadead/dotfiles-private.git {{ private }} || {
            echo "Failed to clone private repo. Is SSH configured?"
            echo "Set up SSH first, then run: just init"
            exit 1
        }
    else
        echo "Private repo already exists at {{ private }}"
    fi
    echo "Applying public dotfiles..."
    chezmoi apply
    echo "Applying private dotfiles..."
    chezmoi --source {{ private }} apply
    echo "Done."

# ─────────────────────────────────────────────────────────────────────────────
# Apply
# ─────────────────────────────────────────────────────────────────────────────

# Apply both public and private dotfiles
apply: apply-public apply-private

# Apply public dotfiles only
apply-public:
    chezmoi apply

# Apply private dotfiles only
[no-exit-message]
apply-private:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -d {{ private }} ]; then
        echo "Private repo not found. Run: just init"
        exit 1
    fi
    chezmoi --source {{ private }} apply

# ─────────────────────────────────────────────────────────────────────────────
# Edit & Add
# ─────────────────────────────────────────────────────────────────────────────

# Edit a managed file (opens in $EDITOR, applies on save)
edit file:
    chezmoi edit {{ file }}

# Add a file to public dotfiles
add file:
    chezmoi add {{ file }}

# Add a file to private dotfiles
add-private file:
    chezmoi --source {{ private }} add {{ file }}

# Re-add a changed managed file
re-add file:
    chezmoi re-add {{ file }}

# ─────────────────────────────────────────────────────────────────────────────
# Sync
# ─────────────────────────────────────────────────────────────────────────────

# Pull latest and apply both repos
[no-exit-message]
pull:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== Public ==="
    chezmoi update
    if [ -d {{ private }} ]; then
        echo ""
        echo "=== Private ==="
        git -C {{ private }} pull --rebase
        chezmoi --source {{ private }} apply
    fi

# Push both repos
[no-exit-message]
push:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== Public ==="
    cd {{ public }}
    BRANCH=$(git branch --show-current)
    git push origin "$BRANCH"
    if [ -d {{ private }} ]; then
        echo ""
        echo "=== Private ==="
        cd {{ private }}
        BRANCH=$(git branch --show-current)
        git push origin "$BRANCH"
    fi

# Show git status of both repos
[no-exit-message]
status:
    #!/usr/bin/env bash
    echo "=== Public ({{ public }}) ==="
    git -C {{ public }} status --short
    if [ -d {{ private }} ]; then
        echo ""
        echo "=== Private ({{ private }}) ==="
        git -C {{ private }} status --short
    else
        echo ""
        echo "=== Private: not cloned ==="
    fi

# ─────────────────────────────────────────────────────────────────────────────
# Info
# ─────────────────────────────────────────────────────────────────────────────

# Show pending changes for both repos
[no-exit-message]
diff:
    #!/usr/bin/env bash
    echo "=== Public ==="
    chezmoi diff || true
    if [ -d {{ private }} ]; then
        echo ""
        echo "=== Private ==="
        chezmoi --source {{ private }} diff || true
    fi

# List all managed files
[no-exit-message]
managed:
    #!/usr/bin/env bash
    echo "=== Public ($(chezmoi managed | wc -l | tr -d ' ') files) ==="
    chezmoi managed
    if [ -d {{ private }} ]; then
        echo ""
        echo "=== Private ($(chezmoi --source {{ private }} managed | wc -l | tr -d ' ') files) ==="
        chezmoi --source {{ private }} managed
    fi

# Run chezmoi doctor
doctor:
    chezmoi doctor

# Verify all managed files are in sync
[no-exit-message]
verify:
    #!/usr/bin/env bash
    echo "=== Public ==="
    chezmoi verify && echo "In sync." || echo "Drift detected — run: just diff"
    if [ -d {{ private }} ]; then
        echo ""
        echo "=== Private ==="
        chezmoi --source {{ private }} verify && echo "In sync." || echo "Drift detected — run: just diff"
    fi

# Full health check: chezmoi, git, managed files, hooks
[no-exit-message]
check:
    #!/usr/bin/env bash
    set -uo pipefail
    PASS=0; FAIL=0; TOTAL=0
    DIM="\033[0;90m"; GREEN="\033[0;32m"; RED="\033[0;31m"; BOLD="\033[1m"; RST="\033[0m"
    check() {
        ((TOTAL++))
        if eval "$2" >/dev/null 2>&1; then
            printf "${GREEN}✓${RST} %s\n" "$1"; ((PASS++))
        else
            printf "${RED}✗${RST} %s\n" "$1"; ((FAIL++))
            if [ -n "${3:-}" ]; then
                eval "$3" 2>/dev/null | while IFS= read -r line; do
                    printf "${DIM}  │ %s${RST}\n" "$line"
                done
            fi
        fi
    }
    section() { printf "\n${DIM}─── %s${RST}\n" "$1"; }
    PUB=$(chezmoi managed 2>/dev/null | wc -l | tr -d ' ')
    PRIV=$(chezmoi --source {{ private }} managed 2>/dev/null | wc -l | tr -d ' ')
    printf "${BOLD}dotfiles${RST} ${DIM}· %s public · %s private${RST}\n" "$PUB" "$PRIV"
    section "tools"
    check "chezmoi"                   "command -v chezmoi"
    check "git"                       "command -v git"
    check "just"                      "command -v just"
    check "1Password SSH agent"       "test -S \"$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\""
    section "sources"
    check "public  ~/.dotfiles"       "test -d {{ public }}"
    check "private ~/.dotfiles-private" "test -d {{ private }}"
    check "chezmoi.toml"              "test -f ~/.config/chezmoi/chezmoi.toml"
    check "git hooks"                 "test -f {{ public }}/.githooks/pre-commit"
    section "state"
    check "public repo clean" \
        "test -z \"\$(git -C {{ public }} status --porcelain)\"" \
        "git -C {{ public }} status --short"
    check "private repo clean" \
        "test -z \"\$(git -C {{ private }} status --porcelain)\"" \
        "git -C {{ private }} status --short"
    check "public in sync" \
        "chezmoi verify" \
        "chezmoi diff --no-pager 2>&1 | grep '^diff' | sed 's|diff --git a/||;s| b/.*||' | head -10"
    check "private in sync" \
        "chezmoi --source {{ private }} verify" \
        "chezmoi --source {{ private }} diff --no-pager 2>&1 | grep '^diff' | sed 's|diff --git a/||;s| b/.*||' | head -10"
    printf "\n${BOLD}%s${RST}/${DIM}%s${RST}" "$PASS" "$TOTAL"
    if [ "$FAIL" -gt 0 ]; then
        printf " ${RED}(%s failed)${RST}\n" "$FAIL"
    else
        printf " ${GREEN}all clear${RST}\n"
    fi
