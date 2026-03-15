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

# set default app for file extensions via duti
# each entry is either a .extension or a UTI (no leading dot)
_mrgsh_duti_types=(
	.ts .tsx .js .jsx .json .yml .yaml .toml .xml
	.css .scss .md .txt .sh .env .gitignore
	.py .rb .go .rs .swift .kt .java .c .cpp .h
	.php .sql .graphql .proto .ini .conf .log
	public.plain-text
	public.source-code
)

function _mrgsh_set_default_app() {
	_mrgsh_check_tools duti || return 1
	[[ "$(_mrgsh_get_system)" != "macos" ]] && { echo "Error: duti is macOS only." >&2; return 1; }

	local app="${1:-com.microsoft.VSCode}"
	local total=${#_mrgsh_duti_types[@]}
	local ok=0 fail=0 i=0

	local reset=$'\033[0m'
	local dim=$'\033[2m'
	local green=$'\033[32m'
	local yellow=$'\033[33m'
	local red=$'\033[31m'
	local cyan=$'\033[36m'

	echo "${cyan}Setting ${app##*.} as default for $total types...${reset}"
	echo

	for entry in "${_mrgsh_duti_types[@]}"; do
		((i++))
		if duti -s "$app" "$entry" all 2>/dev/null; then
			((ok++))
			printf "  ${green}✓${reset} ${dim}[%2d/%d]${reset} %s\n" "$i" "$total" "$entry"
		else
			((fail++))
			printf "  ${red}✗${reset} ${dim}[%2d/%d]${reset} ${yellow}%s${reset} ${dim}(skipped)${reset}\n" "$i" "$total" "$entry"
		fi
	done

	echo
	echo "${green}✓ $ok set${reset}${fail:+, ${yellow}✗ $fail skipped${reset}}"
}
