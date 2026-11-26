# shellcheck shell=bash disable=SC2154
mkdir -p "$SB/repoA" "$SB/repoB"
for r in repoA repoB; do
	git -C "$SB/$r" init -q
	git -C "$SB/$r" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
done
printf 'plain side text\n' >"$SB/repoA/notes.txt"
printf '# Side Heading\n\nbody\n' >"$SB/repoA/guide.md"

G=$(R new --json side --cwd "$SB/repoA" -- zsh -f -i | jq -r .session_id)
gA=$(R api call -s "$G" session.list_blocks | jq -r '.blocks[0].block_id')
sleep 0.5
gview() { R api call -s "$G" session.view; }
gwin() { gview | jq -r .active_window_id; }
W=$(gwin)
side() { R "do" -s "$G" --json "$@" 2>/dev/null | jq -r '"\(.state) \(.block_id)"' || true; }
g_focus_zoom() {
	gview | jq -r '.active_window_id as $a | .windows[]
		| select(.window_id == $a) | "\(.focused_block_id) \(.zoomed_block_id)"'
}
gplace() { blocks "$G" | awk -v i="$1" '$3 == i { print $2 }'; }
gsplit() {
	gview | jq -r --arg w "$W" --arg b "$1" '[.windows[] | select(.window_id == $w)
		| .layers[].layout | .. | objects | select(.split?) | .split
		| select(.after.block_id == $b)
		| "\(.direction) \(.ratio) \(.before.block_id // "split")"][0]'
}
gscreen() { grep -qF "$2" <<<"$(R capture -s "$G" -b "$1" 2>/dev/null)"; }
ggone() { ! grep -qF "$1" <<<"$(blocks "$G")"; }

s=$(side side_git)
g1=${s#* }
check "side_git opens a side pane" test "${s% *}" = created
check "the git side pane is labelled for its tab" has_label "$G" "side:git:$W"
check "the side pane opens right of the main pane at 0.6" \
	test "$(gsplit "$g1")" = "horizontal 0.6 $gA"
check "the new side pane has focus" test "$(g_focus_zoom)" = "$g1 null"
check "the git side pane runs lazygit in the login shell's PATH" until5 gscreen "$g1" Status

check "side_git on the focused side pane hides it" test "$(side side_git)" = "hidden $g1"
check "a hidden side pane is stashed" test "$(gplace "$g1")" = detached
check "hiding the side pane focuses the main pane" test "$(g_focus_zoom)" = "$gA null"

R zoom -s "$G" "$gA" --on >/dev/null
check "side_git shows the stashed pane again" test "$(side side_git)" = "shown $g1"
check "the shown side pane is placed at 0.6 with focus and no zoom" \
	test "$(gplace "$g1") $(gsplit "$g1") $(g_focus_zoom)" = \
	"placed horizontal 0.6 $gA $g1 null"
side side_git >/dev/null
check "hiding the side pane gives back the main pane's zoom" \
	test "$(g_focus_zoom)" = "$gA $gA"

side side_git >/dev/null
R focus -s "$G" "$gA" >/dev/null
check "side_git on a shown, unfocused side pane focuses it" \
	test "$(side side_git) $(gplace "$g1")" = "focused $g1 placed"

check "side_reader with no file and no reader says so" \
	fails_with "$G" "no file to read" side_reader
s=$(side side_reader "file=$SB/repoA/notes.txt")
rd=${s#* }
check "side_reader from a focused side pane opens beside the main pane" \
	test "${s% *} $(gsplit "$rd")" = "created horizontal 0.6 $gA"
check "the reader shows a plain file with bat" until5 gscreen "$rd" 'plain side text'
R send -s "$G" -b "$rd" q >/dev/null
check "quitting the viewer closes the side pane" until5 ggone "$rd"
s=$(side side_reader "file=$SB/repoA/guide.md")
md=${s#* }
check "the reader shows Markdown with glow" until5 gscreen "$md" 'Side Heading'
s=$(side side_reader "file=$SB/repoA/notes.txt")
check "side_reader with a file replaces the reader pane" \
	test "${s% *} $(ggone "$md" && echo gone)" = "created gone"
R block close -s "$G" "${s#* }" >/dev/null 2>&1 || true

R focus -s "$G" "$g1" >/dev/null
side side_git >/dev/null
R send -s "$G" -b "$gA" "cd '$SB/repoB'"$'\n' >/dev/null
sleep 0.5
s=$(side side_git)
g2=${s#* }
check "side_git after the main pane moved to another repository opens a new pane" \
	test "${s% *} $([[ "$g2" != "$g1" ]] && echo new) $(ggone "$g1" && echo gone)" = \
	"created new gone"

R api call -s "$G" session.new_window "$(jq -cn --arg s "$G" '{session_id: $s, focus: true,
	layout: {block: {flavor: "com.superlogical.terminal.shell",
	options: {command: ["sh", "-c", "exec sleep 300"]}}}}')" >/dev/null
W2=$(gwin)
s=$(side side_git)
g3=${s#* }
check "side_git in a second tab opens its own pane" \
	test "${s% *} $(blocks "$G" | awk -v i="$g3" '$3 == i { print $1 }')" = "created side:git:$W2"
side side_git >/dev/null
t2=$(gview | jq -r --arg w "$W2" '.windows[] | select(.window_id == $w)
	| .layers[0].blocks[0].block_id')
R block close -s "$G" "$t2" >/dev/null
home_tab() { [[ "$(gwin)" == "$W" ]]; }
until5 home_tab || true
side side_git >/dev/null
check "a press closes a stashed side pane whose tab is gone" ggone "$g3"

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
check "drawer_scratch on a drawer behind the focus brings it forward in place" \
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
check "drawer_scratch in a session with no windows says so" \
	fails_with "$E" "no active window" drawer_scratch
check "side_git in a session with no windows says so" \
	fails_with "$E" "no active window" side_git
