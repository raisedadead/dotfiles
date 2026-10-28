#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2155
set -uo pipefail

SELF="$0"
# shellcheck source=/dev/null
. "$(dirname "$0")/colors.sh"

_ico_session=$'\U000F018D'
_ico_project=$'\U000F0770'
_ico_config=$'\U000F0493'
_ico_zoxide=$'\U000F02DA'
_ico_search=$'\U000F0349'
_ico_files=$'\U000F0219'
_ico_text=$'\U000F0284'
_ico_bookmark=$'\U000F00C0'

DIM="$CLR_DIM"
HI="$CLR_HI"
ACCENT="$CLR_ACCENT"
SUB="$CLR_SUB"
RST="$CLR_RST"

_CLR_SESS="$CLR_GREEN"
_CLR_PROJ="$CLR_HI"
_CLR_CONF="$CLR_ACCENT"
_CLR_ZOX="$CLR_MAUVE"

PROJECTS_JSON="$HOME/.config/switcher/projects.json"
BOOKMARKS_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/switcher/bookmarks"
TAB_FILE="${SWITCHER_TAB_FILE:-}"

expand_tilde() { echo "${1/#\~/$HOME}"; }
shorten() { echo "${1/#$HOME/\~}"; }

bookmarks_raw() {
	[[ -f "$BOOKMARKS_FILE" ]] && cat "$BOOKMARKS_FILE"
	return 0
}

_BM_SET=$'\n'"$(bookmarks_raw)"$'\n'
is_bookmarked() { [[ -n "$1" && "$_BM_SET" == *$'\n'"$1"$'\n'* ]]; }

toggle_bookmark() {
	local path="${1%/}" tmp rc
	[[ -n "$path" && -d "$path" ]] || return 1
	mkdir -p "${BOOKMARKS_FILE%/*}" || return 1
	if is_bookmarked "$path"; then
		tmp=$(mktemp "${BOOKMARKS_FILE}.XXXXXX") || return 1
		rc=0
		grep -vxF -- "$path" "$BOOKMARKS_FILE" >"$tmp" 2>/dev/null || rc=$?
		if ((rc > 1)); then
			rm -f "$tmp"
			return 1
		fi
		mv "$tmp" "$BOOKMARKS_FILE" || rm -f "$tmp"
	else
		printf '%s\n' "$path" >>"$BOOKMARKS_FILE"
	fi
}

render_line() {
	local cat="$1" target="$2" path="$3"
	local name short icon cat_label cat_color mark
	short=$(shorten "$path")
	case "$cat" in
	sess)
		name="$target"
		icon="$_ico_session"
		cat_label="session"
		cat_color="$_CLR_SESS"
		;;
	proj)
		name=$(basename "$path")
		icon="$_ico_project"
		cat_label="project"
		cat_color="$_CLR_PROJ"
		;;
	conf)
		name=$(basename "$path")
		icon="$_ico_config"
		cat_label="config"
		cat_color="$_CLR_CONF"
		;;
	zox)
		name=$(basename "$path")
		icon="$_ico_zoxide"
		cat_label="zoxide"
		cat_color="$_CLR_ZOX"
		;;
	*) return ;;
	esac
	if is_bookmarked "$path"; then mark="${ACCENT}${_ico_bookmark}${RST}  "; else mark="   "; fi
	printf '%s|%s|%s\t%s%s%s  %-20s%s\t%s%-7s%s\t%s%s%s\n' \
		"$cat" "$target" "$path" \
		"$mark" "$HI" "$icon" "$name" "$RST" \
		"$cat_color" "$cat_label" "$RST" \
		"$DIM" "$short" "$RST"
}

render_all() {
	while IFS='|' read -r _score cat target path; do
		render_line "$cat" "$target" "$path"
	done
}

tuios_sessions() {
	local panes
	panes=$(tuios list-windows --all --json 2>/dev/null) || return 0
	tuios ls --json 2>/dev/null | jq -r --argjson p "$panes" '
    .[]? | .name as $n |
    ([$p.panes[]? | select(.session == $n)] | (map(select(.focused))[0] // .[0]).cwd // "") as $cwd |
    "\(.last_active // 0)|\($n)|\($cwd)"' 2>/dev/null
}

session_score() {
	local age=$(($2 - $1))
	if ((age < 3600)); then
		echo "$(($3 + 8000))"
	elif ((age < 86400)); then
		echo "$(($3 + 4000))"
	elif ((age < 604800)); then
		echo "$(($3 + 1500))"
	else
		echo "$(($3 + 500))"
	fi
}

config_dirs() {
	local dirs=() d
	if [[ -f "$PROJECTS_JSON" ]] && command -v jq >/dev/null 2>&1; then
		while IFS= read -r d; do
			d=$(expand_tilde "$d")
			[[ -d "$d" ]] && dirs+=("$d")
		done < <(jq -r '.configDirs[]? // empty' "$PROJECTS_JSON" 2>/dev/null)
	fi
	[[ ${#dirs[@]} -eq 0 ]] && dirs=(
		"$HOME/.config/nvim" "$HOME/.config/tuios"
		"$HOME/.config/ghostty" "$HOME/.dotfiles"
	)
	for d in "${dirs[@]}"; do [[ -d "$d" ]] && printf '%s\n' "$d"; done
	return 0
}

base_folder_dirs() {
	[[ -f "$PROJECTS_JSON" ]] && command -v jq >/dev/null 2>&1 || return 0
	local base p
	while IFS='|' read -r _scope base; do
		base=$(expand_tilde "$base")
		[[ -d "$base" ]] || continue
		if command -v fd >/dev/null 2>&1; then
			fd -d 1 -t d . "$base" 2>/dev/null | sort
		else
			find "$base" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort
		fi | while IFS= read -r p; do
			p="${p%/}"
			[[ -d "$p" ]] && printf '%s\n' "$p"
		done
	done < <(jq -r '.baseFolders[]? | "\(.scope // "Other")|\(.path)"' "$PROJECTS_JSON" 2>/dev/null)
	return 0
}

favorite_dirs() {
	[[ -f "$PROJECTS_JSON" ]] && command -v jq >/dev/null 2>&1 || return 0
	local fav
	while IFS= read -r fav; do
		fav=$(expand_tilde "$fav")
		fav="${fav%/}"
		[[ -n "$fav" && -d "$fav" ]] && printf '%s\n' "$fav"
	done < <(jq -r '.favorites[]? | select(.enabled != false) | .rootPath // empty' "$PROJECTS_JSON" 2>/dev/null)
	return 0
}

_source_all_raw() {
	local tmpfile now
	tmpfile=$(mktemp /tmp/switcher-merge.XXXXXX)
	now=$(date +%s)

	{
		zoxide query --list --score 2>/dev/null | while read -r score path; do
			[[ -d "$path" ]] || continue
			printf '%s|4|zox||%s\n' "$score" "$path"
		done

		config_dirs | while IFS= read -r d; do printf '50|3|conf||%s\n' "$d"; done

		while IFS= read -r bm; do
			bm="${bm%/}"
			[[ -n "$bm" && -d "$bm" ]] && printf '200|2|proj||%s\n' "$bm"
		done < <(bookmarks_raw)

		base_folder_dirs | while IFS= read -r p; do printf '100|2|proj||%s\n' "$p"; done
		favorite_dirs | while IFS= read -r p; do printf '200|2|proj||%s\n' "$p"; done

		tuios_sessions | while IFS='|' read -r last name path; do
			printf '%s|1|sess|%s|%s\n' "$(session_score "$last" "$now" 100000)" "$name" "${path:-$name}"
		done
	} >>"$tmpfile"

	sort -t'|' -k5,5 -k2,2n "$tmpfile" | awk -F'|' '
  {
    score=$1+0; cat=$3; target=$4; path=$5
    if (path == last_path) {
      if (score > best_score) best_score = score
    } else {
      if (last_path != "") printf "%s|%s|%s|%s\n", best_score, best_cat, best_target, last_path
      last_path=path; best_score=score; best_cat=cat; best_target=target
    }
  }
  END { if (last_path != "") printf "%s|%s|%s|%s\n", best_score, best_cat, best_target, last_path }
  ' | sort -t'|' -k1,1 -rn

	rm -f "$tmpfile"
}

source_all() { _source_all_raw | render_all; }

source_sess() {
	local now
	now=$(date +%s)
	tuios_sessions | while IFS='|' read -r last name path; do
		printf '%s|sess|%s|%s\n' "$(session_score "$last" "$now" 0)" "$name" "$path"
	done | sort -t'|' -k1,1 -rn | render_all
}

source_proj() {
	local seen=$'\n' p
	while IFS= read -r p; do
		p="${p%/}"
		[[ -n "$p" && -d "$p" ]] || continue
		[[ "$seen" == *$'\n'"$p"$'\n'* ]] && continue
		seen+="$p"$'\n'
		render_line "proj" "" "$p"
	done < <(
		bookmarks_raw
		favorite_dirs
		base_folder_dirs
	)
}

source_conf() {
	local d
	while IFS= read -r d; do render_line "conf" "" "$d"; done < <(config_dirs)
}

source_zox() {
	zoxide query --list --score 2>/dev/null | while read -r _score path; do
		[[ -d "$path" ]] && render_line "zox" "" "$path"
	done
	return 0
}

source_search() {
	local mode="${1:-files}" query="${2:-}" base
	base="${TUIOS_ACTIVE_PANE_CWD:-$PWD}"
	if [[ "$mode" == "text" ]]; then
		[[ -n "$query" ]] || return 0
		rg --json --hidden --glob '!.git' -- "$query" "$base" 2>/dev/null |
			jq --unbuffered -r --arg hi "$HI" --arg icon "$_ico_text" --arg base "${base%/}/" '
        select(.type == "match") | .data |
        (.path.text // (.path.bytes | @base64d)) as $path |
        "search|\(.line_number)|\($path | @base64)\t\($hi)\($icon)  " +
        (("\($path | ltrimstr($base)):\(.line_number):" + (.lines.text // (.lines.bytes | @base64d))) |
          gsub("[\u0000-\u001f\u007f]"; " "))'
	else
		fd --hidden --exclude .git --type f --type d --print0 . "$base" 2>/dev/null |
			perl -0 -MMIME::Base64=encode_base64 -e '
        my ($home, $hi, $icon, $dim, $rst, $accent, $bookmark, $store) = @ARGV;
        my %bookmarks;
        if (open my $fh, "<", $store) { local $/ = "\n"; while (<$fh>) { chomp; $bookmarks{$_} = 1 } }
        $| = 1;
        while (<STDIN>) {
          chomp; s{/$}{};
          my $path = $_;
          my $encoded = encode_base64($path, "");
          my $short = $path; $short =~ s/^\Q$home\E(?=\/|$)/~/;
          my ($name) = $path =~ m{([^/]+)$};
          for ($name, $short) { s/[\x00-\x1f\x7f]/ /g }
          my $mark = $bookmarks{$path} ? "$accent$bookmark$rst  " : "   ";
          printf "search||%s\t%s%s%s  %-22s%s\t%ssrch%s\t%s%s%s\n",
            $encoded, $mark, $hi, $icon, $name, $rst, $dim, $rst, $dim, $short, $rst;
        }
      ' "$HOME" "$HI" "$_ico_files" "$DIM" "$RST" "$ACCENT" "$_ico_bookmark" "$BOOKMARKS_FILE"
	fi
}

do_source() {
	[[ -n "$TAB_FILE" ]] && printf '%s %s\n' "$1" "${2:-}" >"$TAB_FILE"
	case "$1" in
	all) source_all ;;
	sess) source_sess ;;
	proj) source_proj ;;
	conf) source_conf ;;
	zox) source_zox ;;
	search) source_search "${2:-files}" "${3:-}" ;;
	*)
		echo "Unknown source: $1" >&2
		exit 1
		;;
	esac
}

_internal() { cut -f1 <<<"$1"; }
extract_cat() { _internal "$1" | cut -d'|' -f1; }
extract_target() { _internal "$1" | cut -d'|' -f2; }
extract_path() {
	if [[ $(extract_cat "$1") == search ]]; then
		_internal "$1" | cut -d'|' -f3 | base64 --decode
	else
		_internal "$1" | cut -d'|' -f3-
	fi
}

eza_tree() {
	eza --tree --level=2 --icons --color=always --group-directories-first \
		--ignore-glob='node_modules|.git|__pycache__|.next|dist|build|.cache|.turbo|vendor' \
		"$1" 2>/dev/null || ls -la "$1" 2>/dev/null
}

do_preview() {
	local entry="$1"
	local cat target path
	cat=$(extract_cat "$entry")
	target=$(extract_target "$entry")
	path=$(extract_path "$entry")

	case "$cat" in
	sess)
		local wid
		wid=$(tuios list-windows --all --json 2>/dev/null | jq -r --arg s "$target" '
      [.panes[]? | select(.session == $s)] | (map(select(.focused))[0] // .[0]).window_id // empty')
		[[ -n "$wid" ]] && tuios capture-pane -s "$target" -w "$wid" --ansi --trim 2>/dev/null ||
			echo "No preview available"
		;;
	proj | conf | zox)
		local readme="" f
		for f in "$path"/README.md "$path"/readme.md "$path"/README "$path"/README.rst; do
			[[ -f "$f" ]] && readme="$f" && break
		done
		if [[ -n "$readme" ]]; then
			bat -n --color=always --style=plain "$readme" 2>/dev/null
		else
			eza_tree "$path"
		fi
		;;
	search)
		if [[ -d "$path" ]]; then
			eza_tree "$path"
		elif [[ -f "$path" ]]; then
			if [[ $(file --brief --mime-encoding -- "$path") == binary ]]; then
				file --brief -- "$path"
			elif [[ -n "$target" ]]; then
				bat --color=always --style=numbers --highlight-line "$target" \
					--line-range "$((target > 20 ? target - 20 : 1)):$((target + 50))" -- "$path"
			else
				bat --color=always --style=numbers --line-range=:500 -- "$path"
			fi
		fi
		;;
	esac
}

open_in_editor() {
	local path="$1" line="${2:-}"
	if [[ -f "$path" ]]; then
		local -a args=("$path")
		[[ -n "$line" ]] && args=("+$line" "$path")
		tuios new-window --cwd "$(dirname "$path")" "$(basename "$path")" -- "${EDITOR:-nvim}" "${args[@]}" >/dev/null
	else
		tuios new-window --cwd "$path" "$(basename "$path")" -- "${EDITOR:-nvim}" >/dev/null
	fi
}

session_exists() {
	tuios ls --json 2>/dev/null | jq -e --arg s "$1" 'any(.[]?; .name == $s)' >/dev/null
}

session_at() {
	tuios list-windows --all --json 2>/dev/null | jq -e --arg s "$1" --arg p "$2" \
		'any(.panes[]?; .session == $s and ((.cwd // "") == $p or ((.cwd // "") | startswith($p + "/"))))' >/dev/null
}

tuios_connect() {
	local path="$1" base name suffix=2
	base=$(basename "$path" | sed -e 's/^\.//' -e 's/:/_/g' -e 's/^-/_/')
	name="$base"
	while session_exists "$name" && ! session_at "$name" "$path"; do
		name="${base}-${suffix}"
		((suffix++))
	done
	tuios switch-session --create --cwd "$path" "$name" >/dev/null
}

kill_session() {
	local session="$1" answer=""
	printf 'Kill %s? (y/n) ' "$session"
	read -r -n 1 answer
	[[ "$answer" == y ]] && tuios kill-session "$session" >/dev/null
	return 0
}

do_action() {
	local entry="$1" key="${2:-}"
	local cat target path
	cat=$(extract_cat "$entry")
	target=$(extract_target "$entry")
	path=$(extract_path "$entry")

	case "$cat" in
	sess)
		case "$key" in
		ctrl-d) kill_session "$target" ;;
		ctrl-e) [[ -d "$path" ]] && open_in_editor "$path" ;;
		ctrl-v) [[ -d "$path" ]] && "${VISUAL:-zed}" "$path" ;;
		*) tuios switch-session "$target" >/dev/null ;;
		esac
		;;
	proj | conf | zox)
		case "$key" in
		ctrl-e) open_in_editor "$path" ;;
		ctrl-v) "${VISUAL:-zed}" "$path" ;;
		*) tuios_connect "$path" ;;
		esac
		;;
	search)
		if [[ -n "$target" ]]; then
			case "$key" in
			ctrl-v) "${VISUAL:-zed}" "$path:$target" ;;
			*) open_in_editor "$path" "$target" ;;
			esac
		elif [[ -d "$path" ]]; then
			case "$key" in
			ctrl-e) open_in_editor "$path" ;;
			ctrl-v) "${VISUAL:-zed}" "$path" ;;
			*) tuios_connect "$path" ;;
			esac
		elif [[ -f "$path" ]]; then
			case "$key" in
			ctrl-v) "${VISUAL:-zed}" "$path" ;;
			*) open_in_editor "$path" ;;
			esac
		fi
		;;
	esac
}

make_header() {
	local active="$1" i
	local -a items=("All" "Sessions" "Projects" "Zoxide" "Files" "Grep")
	local -a keys=("<C-a>" "<C-t>" "<C-p>" "<C-z>" "<C-f>" "<C-g>")
	local result="  " first=1
	for i in "${!items[@]}"; do
		[[ "$first" == "1" ]] && first=0 || result+=" ${DIM}·${RST} "
		if [[ "${items[$i]}" == "$active" ]]; then
			result+="${ACCENT}${keys[$i]} ${items[$i]}${RST}"
		else
			result+="${SUB}${keys[$i]} ${items[$i]}${RST}"
		fi
	done
	printf '%s' "$result"
}

case "${1:-}" in
--source)
	do_source "${2:-all}" "${3:-}" "${4:-}"
	exit
	;;
--preview)
	do_preview "$2"
	exit
	;;
--bookmark)
	toggle_bookmark "$(extract_path "$2")" &&
		printf 'reload(%s --source-current)' "$SELF"
	exit 0
	;;
--source-current)
	if [[ -n "$TAB_FILE" && -s "$TAB_FILE" ]]; then
		read -r _tab _arg <"$TAB_FILE"
		do_source "${_tab:-all}" "${_arg:-}"
	else
		do_source all
	fi
	exit
	;;
esac

SWITCHER_TAB_FILE=$(mktemp /tmp/switcher-tab.XXXXXX)
export SWITCHER_TAB_FILE
TAB_FILE="$SWITCHER_TAB_FILE"
trap 'rm -f "$SWITCHER_TAB_FILE"' EXIT
printf 'all \n' >"$TAB_FILE"

FOOTER_NAV="${DIM}  Connect <CR> ◆ Bookmark <C-s> ◆ Editor <C-e> ◆ Zed <C-v> ◆ Kill <C-d> ◆ Preview <C-/>${RST}"
FOOTER_SESS="${DIM}  Switch <CR> ◆ Bookmark <C-s> ◆ Kill <C-d> ◆ Preview <C-/>${RST}"
FOOTER_FSRCH="${DIM}  Open <CR> ◆ Editor <C-e> ◆ Zed <C-v> ◆ Preview <C-/> ◆ Text grep <C-g>${RST}"
FOOTER_GSRCH="${DIM}  Open <CR> ◆ Editor <C-e> ◆ Zed <C-v> ◆ Files <C-f> ◆ Regex query${RST}"

HDR_ALL=$(make_header "All")
HDR_SESS=$(make_header "Sessions")
HDR_PROJ=$(make_header "Projects")
HDR_ZOX=$(make_header "Zoxide")
HDR_FSRCH=$(make_header "Files")
HDR_GSRCH=$(make_header "Grep")

BIND_ALL="unbind(change)+enable-search+reload($SELF --source all)+change-prompt($_ico_project  All ❯ )+change-header($HDR_ALL)+change-footer($FOOTER_NAV)"
BIND_SESS="unbind(change)+enable-search+reload($SELF --source sess)+change-prompt($_ico_session  Sessions ❯ )+change-header($HDR_SESS)+change-footer($FOOTER_SESS)"
BIND_PROJ="unbind(change)+enable-search+reload($SELF --source proj)+change-prompt($_ico_project  Projects ❯ )+change-header($HDR_PROJ)+change-footer($FOOTER_NAV)"
BIND_ZOX="unbind(change)+enable-search+reload($SELF --source zox)+change-prompt($_ico_zoxide  Zoxide ❯ )+change-header($HDR_ZOX)+change-footer($FOOTER_NAV)"
BIND_FSRCH="unbind(change)+enable-search+reload($SELF --source search files)+change-prompt($_ico_files  Files ❯ )+change-header($HDR_FSRCH)+change-footer($FOOTER_FSRCH)"
BIND_MARK="transform($SELF --bookmark {})"
BIND_GSRCH="disable-search+rebind(change)+reload($SELF --source search text {q})+change-prompt($_ico_text  Grep ❯ )+change-header($HDR_GSRCH)+change-footer($FOOTER_GSRCH)+hide-preview"

result=$(source_all | fzf \
	--ansi --no-info --cycle --tiebreak=begin,index --no-keep-right \
	--delimiter $'\t' --with-nth '2..' --nth '1,3..' \
	--height=100% --border=none --padding=1,2 \
	--color "$FZF_MOCHA_COLORS,bg:-1" \
	--header "$HDR_ALL" \
	--header-first --header-border=line \
	--prompt "$_ico_project  All ❯ " \
	--footer "$FOOTER_NAV" \
	--footer-border=line \
	--preview "$SELF --preview {}" \
	--preview-window 'bottom:30%:wrap:hidden' \
	--bind "start:unbind(change)" \
	--bind "change:reload($SELF --source search text {q})" \
	--bind "ctrl-a:$BIND_ALL" \
	--bind "ctrl-t:$BIND_SESS" \
	--bind "ctrl-p:$BIND_PROJ" \
	--bind "ctrl-z:$BIND_ZOX" \
	--bind "ctrl-f:$BIND_FSRCH" \
	--bind "ctrl-g:$BIND_GSRCH" \
	--bind "ctrl-s:$BIND_MARK" \
	--bind 'ctrl-/:toggle-preview' \
	--bind 'ctrl-o:toggle-preview' \
	--expect 'ctrl-e,ctrl-v,ctrl-d' \
	--bind 'esc:abort')

[[ -z "$result" ]] && exit 0

key=$(head -1 <<<"$result")
entry=$(tail -1 <<<"$result")

[[ -z "$entry" ]] && exit 0

do_action "$entry" "$key"
