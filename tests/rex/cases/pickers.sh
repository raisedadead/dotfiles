# shellcheck shell=bash disable=SC2154
ids() { R "do" -s "$1" --json "${@:2}" 2>/dev/null | jq -r '[.rows[].id] | join(" ")' || true; }
said() {
	local s=$1 pat=$2
	shift 2
	grep -qF "$pat" <<<"$(R "do" -s "$s" "$@" 2>&1)"
}

long="https://example.com/oauth/authorize?client_id=$(printf 'a%.0s' $(seq 90))&state=xyz"
wrapped=$(split sh -c "echo 'long $long'; exec sleep 300")
gh=https://github.com/o/r/pull/42 bel=https://example.com/bel
osc_fmt="see \033]8;;$gh\033\\\\PR #42\033]8;;\033\\\\ and "
osc_fmt+="\033]8;id=7;$bel\007bel\033]8;;\007 now\n"
osc=$(split sh -c "printf '$osc_fmt'; exec sleep 300")
rust="https://en.wikipedia.org/wiki/Rust_(programming_language)"
parens=$(split sh -c "echo '$rust [docs](https://example.com/docs) (see http://x.example/y).'
	exec sleep 300")
gap_fmt='https://t.example/a\tnext\nhttps://e.example/q\033[5Cgap\n'
gap_fmt+='\033[3Ghttps://g.example/c\033[40Gcol40\n'
gap_fmt+='\033[4;1Hhttps://d.example/p\033[4;40Hcol40\n'
gaps=$(split sh -c "printf '$gap_fmt'; exec sleep 300")
sleep 0.5
links_of() { ids "$S" rows_link "block=$1"; }
check "rows_link lists each link once" \
	test "$(links_of "$linky" | tr ' ' '\n' | sort | tr '\n' ' ')" = "http://x.test/b https://example.com/a "
check "rows_link ends a URL at a gap in the line" test "$(links_of "$gaps")" = \
	"https://d.example/p https://g.example/c https://e.example/q https://t.example/a"
check "rows_link joins a URL that wraps at the pane edge" test "$(links_of "$wrapped")" = "$long"
check "rows_link lists OSC 8 link targets" test "$(links_of "$osc")" = "$bel $gh"
check "rows_link keeps balanced parentheses in a URL" \
	test "$(links_of "$parens")" = "http://x.example/y https://example.com/docs $rust"
R "do" -s "$S" pick_link "id=https://example.com/a" >/dev/null
check "pick_link opens the picked URL" file_has "$SB/t/opened" '^https://example.com/a$'
check "pick_link with no app says why" \
	said "$S" 'no answer to "Open a Link": no_client' -b "$linky" pick_link
for b in "$wrapped" "$osc" "$parens" "$gaps"; do R block close -s "$S" "$b" >/dev/null 2>&1 || true; done

mkdir -p "$SB/pk/docs" "$SB/pk/.scratchpad" "$SB/mark" "$SB/zdir"
git -C "$SB/pk" init -q
printf '.scratchpad/\n' >"$SB/pk/.gitignore"
printf '# A\n' >"$SB/pk/docs/a.md"
printf 'code\n' >"$SB/pk/code.txt"
printf '# S\n' >"$SB/pk/.scratchpad/s.md"
git -C "$SB/pk" add -A
git -C "$SB/pk" -c user.name=t -c user.email=t@t commit -q -m init
_ZO_DATA_DIR="$SB/zo" zoxide add "$SB/zdir"
pk=$(cd "$SB/pk" && pwd -P)
K=$(R new --json pk --cwd "$SB/pk" -- zsh -f -i | jq -r .session_id)
sleep 0.5

marks="$SB/state-home/switcher/bookmarks"
R "do" -s "$K" toggle_bookmark "path=$SB/mark/" >/dev/null
check "toggle_bookmark adds the folder without its slash" grep -qxF "$SB/mark" "$marks"
sw=$(R "do" -s "$K" --json rows_switch)
has_row() { jq -e --arg i "$1" --arg c "$2" '.rows | any(.id == $i and .icon == $c)' <<<"$sw" >/dev/null; }
check "rows_switch lists the other sessions" has_row "$S" terminal
check "rows_switch leaves out its own session" not has_row "$K" terminal
check "rows_switch lists the worktrees with wt on the launchd PATH" has_row "dir:$pk" branch
check "rows_switch lists the bookmarks" has_row "dir:$SB/mark" star
zrow() { jq -e '.rows | any((.id | endswith("/zdir")) and .icon == "folder")' <<<"$sw" >/dev/null; }
check "rows_switch lists the zoxide folders" zrow
R "do" -s "$K" toggle_bookmark "path=$SB/mark" >/dev/null
check "toggle_bookmark removes a marked folder" not grep -qxF "$SB/mark" "$marks"
check "toggle_bookmark refuses a missing folder" said "$K" "not a folder" toggle_bookmark "path=$SB/nope"
check "pick_switch with no app says why" said "$K" 'no answer to "Switch": no_client' pick_switch
check "pick_switch to a session asks the app to switch" \
	said "$K" "no client is targeted" pick_switch "id=$S"
labelled() { R ls --json | jq -e --arg l "$1" '.sessions | any(.label == $l)' >/dev/null; }
said "$K" "no client is targeted" pick_switch "id=dir:$SB/mark" || true
check "pick_switch to a folder opens its session" labelled mark
check "pick_switch with a new name asks the app to switch" \
	said "$K" "no client is targeted" pick_switch name=feat-x
check "pick_switch with a new name makes the worktree" \
	grep -q 'feat-x' <<<"$(git -C "$SB/pk" worktree list)"
check "pick_switch with a new name opens the worktree's session" labelled pk-feat-x

rr=$(ids "$K" rows_read)
check "rows_read lists Markdown files with rg on the launchd PATH" grep -q "$pk/docs/a.md" <<<"$rr"
check "rows_read lists the gitignored scratchpad notes" grep -q '\.scratchpad/s\.md' <<<"$rr"
check "rows_read leaves out other files" not grep -q 'code\.txt' <<<"$rr"
check "rows_read any=true lists every file" grep -q 'code\.txt' <<<"$(ids "$K" rows_read any=true)"
mkdir -p "$SB/pk/many"
(cd "$SB/pk/many" && seq 2100 | sed 's/$/.txt/' | xargs touch)
many() { R "do" -s "$K" --json rows_read any=true | jq '.rows | length'; }
check "rows_read keeps a picker under 2,000 rows" test "$(many)" = 2000
rm -rf "$SB/pk/many"
check "pick_read with no app says why" said "$K" 'no answer to "Read a Document": no_client' pick_read
check "pick_read opens the file in the reader side pane" \
	test "$(R "do" -s "$K" --json pick_read "id=$pk/docs/a.md" | jq -r .state)" = created
check "the reader side pane is open" until5 has_label "$K" "side:reader:$(R api call -s "$K" session.view | jq -r .active_window_id)"
R "do" -s "$K" reader_copy_path >/dev/null
check "reader_copy_path copies the path" test "$(cat "$SB/t/copied")" = "$pk/docs/a.md"
R "do" -s "$K" reader_copy_file >/dev/null
check "reader_copy_file copies the contents" test "$(cat "$SB/t/copied")" = "# A"
R "do" -s "$K" reader_edit >/dev/null
check "reader_edit opens the editor in the file's folder" until5 file_has "$SB/t/editor.runs" 'pk/docs$'
check "reader_edit labels the editor pane" has_label "$K" edit:a.md

kr=$(R "do" -s "$S" --json rows_key)
check "rows_key titles each binding with its action" \
	jq -e '.rows | any(.title == "Git Side Pane" and .subtitle == "alt+g")' <<<"$kr"
ki=$(jq -r '[.rows[] | select(.title == "Git Side Pane") | .id][0]' <<<"$kr")
check "pick_key runs the picked binding through the app" \
	said "$S" "no client is targeted" pick_key "id=$ki"
check "pick_key with no app says why" said "$S" 'no answer to "Find a Key": no_client' pick_key

fg_is() {
	local q
	q=$(jq -cn --arg s "$S" --arg b "$1" \
		'{session_id: $s, block_id: $b, method: "process", args: {}}')
	[[ "$(R api call -s "$S" block.method "$q" | jq -r '.foreground.name')" == "$2" ]]
}
ask_close() { R "do" -s "$S" --json close_pane "block=$1" 2>&1 || true; }
answer_close() { R "do" -s "$S" --json close_pane "block=$1" "answer=$2" | jq -r .closed; }
confirm_pane=$(split sh -c 'exec sleep 300')
check "the close target runs sleep" until5 fg_is "$confirm_pane" sleep
check "close_pane asks first and names the program" \
	grep -qF 'no answer to "Close sleep?": no_client' <<<"$(ask_close "$confirm_pane")"
check "close_pane keeps the pane when nobody answers" not gone "$confirm_pane"
check "close_pane keeps the pane on keep" test "$(answer_close "$confirm_pane" keep)" = false
check "close_pane closes the pane on close" test "$(answer_close "$confirm_pane" close)" = true
check "the pane is closed after close" until5 gone "$confirm_pane"

mkdir -p "$SB/claude-versions" "$SB/claude-bin"
cp /bin/sleep "$SB/claude-versions/2.1.316"
codesign --force -s - "$SB/claude-versions/2.1.316" 2>/dev/null
ln -sf "$SB/claude-versions/2.1.316" "$SB/claude-bin/claude"
agent_pane=$(split "$SB/claude-bin/claude" 300)
check "the fake agent runs its version file" until5 fg_is "$agent_pane" 2.1.316
check "close_pane names the agent, not its version file" \
	grep -qF '"Close claude?"' <<<"$(ask_close "$agent_pane")"
R block close -s "$S" "$agent_pane" >/dev/null 2>&1 || true

ask=$(R "do" -s "$S" -b "$plain" --json ask_pane | jq -r '.block_id // empty')
check "close_pane on an agent popup asks first" grep -qF 'no answer to "Close' <<<"$(ask_close "$ask")"
check "close_pane on an agent popup keeps the agent" has_label "$S" popup:ask
R "do" -s "$S" close_pane "block=$ask" answer=close >/dev/null 2>&1 || true
check "close_pane closes an agent popup on close" until5 no_label "$S" popup:ask
tp=$(R "do" -s "$S" --json t_popup label=popup:tp seconds=30 | jq -r .block_id)
check "close_pane on a popup closes it and asks nothing" \
	test "$(R "do" -s "$S" --json close_pane "block=$tp" | jq -r .closed)" = true
