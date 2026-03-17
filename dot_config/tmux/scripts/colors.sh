#!/usr/bin/env bash
# Catppuccin Mocha color palette for tmux popup scripts
# Source this file: . "$(dirname "$0")/colors.sh"

# ANSI true-color escape sequences
CLR_DIM=$'\033[38;2;147;153;178m'    # overlay2 #939ab2
CLR_HI=$'\033[38;2;137;180;250m'     # blue #89b4fa
CLR_ACCENT=$'\033[38;2;249;226;175m' # yellow #f9e2af
CLR_SUB=$'\033[38;2;166;173;200m'    # subtext0 #a6adc8
CLR_GREEN=$'\033[38;2;166;227;161m'  # green #a6e3a1
CLR_RED=$'\033[38;2;243;139;168m'    # red #f38ba8
CLR_MAUVE=$'\033[38;2;203;166;247m'  # mauve #cba6f7
CLR_RST=$'\033[0m'

# fzf --color string (official catppuccin/fzf mocha theme)
FZF_MOCHA_COLORS="bg+:#313244,bg:#1E1E2E,spinner:#F5E0DC,hl:#F38BA8"
FZF_MOCHA_COLORS+=",fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC"
FZF_MOCHA_COLORS+=",marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8"
FZF_MOCHA_COLORS+=",selected-bg:#45475A,border:#6C7086,label:#CDD6F4"
