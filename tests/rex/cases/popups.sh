# shellcheck shell=bash disable=SC2154
urls_of() { strict "$SB/cfg/bin/rex-urls" --list "$S" "$1" | tr '\n' ' '; }

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
check "rex-urls ends a URL at a gap in the line" test "$(urls_of "$gaps")" = \
	"https://d.example/p https://g.example/c https://e.example/q https://t.example/a "
check "rex-urls joins a URL that wraps at the pane edge" test "$(urls_of "$wrapped")" = "$long "
check "rex-urls lists OSC 8 link targets" test "$(urls_of "$osc")" = "$bel $gh "
check "rex-urls keeps balanced parentheses in a URL" \
	test "$(urls_of "$parens")" = "http://x.example/y https://example.com/docs $rust "

pop() {
	local out
	out=$(R "do" -s "$S" -b "$2" --json "$1" 2>/dev/null) || return 0
	jq -r '.block_id // empty' <<<"$out"
}
label_count() { blocks "$S" | awk -v l="$1" '$1 == l' | wc -l | tr -d ' '; }
view_state() {
	R api call -s "$S" session.view | jq -r '.active_window_id as $a | .windows[]
		| select(.window_id == $a) | "\(.focused_block_id) \(.zoomed_block_id)"'
}
screen_has() {
	local s
	for _ in $(seq 50); do
		s=$(R capture -s "$S" -b "$1" 2>/dev/null)
		grep -qiE 'command not found|no such file' <<<"$s" && return 1
		grep -qE "$2" <<<"$s" && return 0
		sleep 0.1
	done
	return 1
}
closed() {
	R block close -s "$S" "$1" >/dev/null 2>&1 || true
	until5 no_label "$S" "$2" || true
}

printf '# Notes\n' >"$SB/proj/notes.md"
here=$(R split -s "$S" --json --cwd "$SB/proj" -- sh -c 'echo https://example.com/proj
	exec sleep 300' | jq -r '.block_ids[0]')
sleep 0.5
R focus -s "$S" "$here" >/dev/null
lg=$(pop popup_lazygit "$here")
check "popup_lazygit shows lazygit" screen_has "$lg" 'Status'
u=$(pop popup_urls "$lg")
check "popup_urls inside a popup lists the pane under it" screen_has "$u" 'example\.com/proj'
toggled() {
	has_label "$S" "$1" || return 1
	pop "${1/:/_}" "$2" >/dev/null
	until5 no_label "$S" "$1"
}
R focus -s "$S" "$here" >/dev/null
check "a popup key inside its popup closes it" toggled popup:urls "$u"
check "the closed popup gives focus back to the popup under it" \
	test "$(view_state)" = "$lg null"
check "alt+g inside lazygit closes it" toggled popup:lazygit "$lg"
w=$(pop popup_workspace "$here")
screen_has "$w" 'workspace ❯' || true
check "alt+w inside the workspace picker closes it" toggled popup:workspace "$w"
check "the closed popup gives focus back to its pane" test "$(view_state)" = "$here null"

ask=$(pop ask_pane "$here")
pop ask_pane "$ask" >/dev/null
check "ask_pane inside its popup keeps the one agent" test "$(label_count popup:ask)" = 1
closed "$ask" popup:ask

calm=$(split sh -c 'exec sleep 300')
sleep 0.3
R zoom -s "$S" "$calm" --on >/dev/null
nolink=$(pop popup_urls "$calm")
check "popup_urls says when a pane has no links" screen_has "$nolink" 'No links in this pane'
for _ in $(seq 40); do
	no_label "$S" popup:urls && break
	sleep 0.1
done
check "a popup that exits gives back focus and zoom" test "$(view_state)" = "$calm $calm"
R focus -s "$S" "$calm" >/dev/null
cp=$(pop popup_keys "$calm")
screen_has "$cp" 'Keybindings' || true
R "do" -s "$S" -b "$cp" close_pane "block=$cp" >/dev/null 2>&1 || true
until5 no_label "$S" popup:keys || true
check "close_pane on a popup gives back focus and zoom" test "$(view_state)" = "$calm $calm"
check "close_pane on a popup asks nothing" no_label "$S" popup:close
asked=$(blocks "$S" | awk '$1 == "popup:close" { print $3 }')
[[ -z "$asked" ]] || closed "$asked" popup:close
R zoom -s "$S" "$calm" --off >/dev/null

p=$(pop popup_reader "$here")
check "popup_reader lists the files" screen_has "$p" ' [1-9][0-9]*/[0-9]+'
full_hints() {
	local s
	s=$(R capture -s "$S" -b "$1")
	grep -qF "C-a All · C-d Docs · C-s Scratch · C-f Files" <<<"$s" &&
		grep -qF "Preview C-/ · Copy C-y · Path C-p · Zed C-v · Edit C-e · Read CR" <<<"$s"
}
check "the reader shows all its key hints at 80 columns" full_hints "$p"
q=$(jq -cn --arg s "$S" --arg b "$p" \
	'{session_id: $s, block_id: $b, method: "resize", args: {columns: 200, rows: 50}}')
R api call -s "$S" block.method "$q" >/dev/null
sleep 0.5
check "the reader shows all its key hints at 200 columns" full_hints "$p"
closed "$p" popup:reader
p=$(pop popup_keys "$here")
check "popup_keys shows the bindings" screen_has "$p" 'Keybindings'
closed "$p" popup:keys
p=$(pop popup_urls "$linky")
check "popup_urls lists the pane's links" screen_has "$p" 'example\.com/a'
closed "$p" popup:urls
bw=$(split env FZF_DEFAULT_OPTS=--color=bw "$SB/cfg/bin/rex-urls" "$S" "$linky")
themed() {
	local s
	for _ in $(seq 30); do
		s=$(R capture -s "$S" -b "$1" --format=vt)
		grep -q 'example\.com/a' <<<"$s" && break
		sleep 0.1
	done
	grep -q '38;2;108;112;134m' <<<"$s"
}
check "the link picker keeps its theme over FZF_DEFAULT_OPTS" themed "$bw"
R block close -s "$S" "$bw" >/dev/null 2>&1 || true

D=$(R new --json dz -- sh -c 'exec sleep 300' | jq -r .session_id)
dA=$(R api call -s "$D" session.list_blocks | jq -r '.blocks[0].block_id')
dB=$(R split -s "$D" --json -- sh -c 'exec sleep 300' | jq -r '.block_ids[0]')
dstate() { R "do" -s "$D" --json drawer_scratch 2>/dev/null | jq -r .state; }
d_focus_zoom() {
	R api call -s "$D" session.view | jq -r '.active_window_id as $a | .windows[]
		| select(.window_id == $a) | "\(.focused_block_id) \(.zoomed_block_id)"'
}
d_layer() {
	R api call -s "$D" session.view | jq -c '[.windows[].layers[]
		| select(any(.blocks[]; .label == "drawer:scratch")) | {layer_id, bounds}][0]'
}
R zoom -s "$D" "$dB" --on >/dev/null
check "the drawer opens" test "$(dstate)" = created
dz=$(R api call -s "$D" session.list_blocks |
	jq -r '.blocks[] | select(.label == "drawer:scratch") | .block_id')
check "hiding the drawer gives back focus and zoom" \
	test "$(dstate) $(d_focus_zoom)" = "hidden $dB $dB"
dstate >/dev/null
q=$(jq -cn --argjson l "$(d_layer)" '{layer_id: $l.layer_id, bounds: [0.5, 0.5, 0.45, 0.45]}')
R api call -s "$D" session.resize_layer "$q" >/dev/null
moved=$(d_layer)
R focus -s "$D" "$dA" >/dev/null
check "alt+t on a drawer behind the focus brings it forward in place" \
	test "$(dstate) $(d_layer) $(d_focus_zoom)" = "shown $moved $dz null"
dstate >/dev/null
dstate >/dev/null
check "the drawer shows again where the operator left it" \
	test "$(d_layer | jq -c .bounds)" = "$(jq -c .bounds <<<"$moved")"
d_layers() {
	R api call -s "$D" session.view |
		jq -c '[.windows[].layers[] | [.kind, (.blocks | length)]]'
}
check "the shown drawer is alone in its layer" \
	test "$(d_layers)" = '[["tiled",2],["floating",1]]'

E=$(R new --json empty -- sh -c 'sleep 0.3' | jq -r .session_id)
no_windows() { [[ "$(R api call -s "$E" session.view | jq '.windows | length')" == 0 ]]; }
until5 no_windows || true
check "alt+t in a session with no windows says so" \
	fails_with "$E" "no active window" drawer_scratch

R focus -s "$S" "$here" >/dev/null
lg=$(pop popup_lazygit "$here")
screen_has "$lg" 'Status' || true
bindings() { R keymap | grep -v '^config: '; }
keys_before=$(bindings) actions_before=$(R actions)
log_at=$(wc -l <"$SB/server.log")
reloads() { R config reload >/dev/null; }
check "the config reloads" reloads
until5 loaded popup_urls || true
check "a reload keeps every key and action" \
	test "$(bindings)$(R actions)" = "$keys_before$actions_before"
check "a reload logs no error" \
	not grep -q ' ERROR ' <<<"$(tail -n +"$((log_at + 1))" "$SB/server.log")"
u=$(pop popup_urls "$lg")
check "after a reload popup_urls inside a popup lists the pane under it" \
	screen_has "$u" 'example\.com/proj'
R focus -s "$S" "$here" >/dev/null
check "after a reload a popup key inside its popup closes it" toggled popup:urls "$u"
check "after a reload the closed popup gives focus back" test "$(view_state)" = "$lg null"
check "after a reload alt+g inside lazygit closes it" toggled popup:lazygit "$lg"
