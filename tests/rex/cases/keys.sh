# shellcheck shell=bash
keys_json=$(R keymap --json)

mkdir -p "$SB/zdot" "$SB/xdg" "$SB/xdg-state" "$SB/xdg-cache"
for f in "$REPO"/dot_config/exact_zsh/*; do
	b=$(basename "$f")
	cp "$f" "$SB/zdot/${b/#dot_/.}"
done
cp -R "$REPO/dot_config/nvim" "$SB/xdg/nvim"
cat >"$SB/nvim-keys.lua" <<'EOF'
vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
local out = {}
for _, mode in ipairs({ "n", "x", "o", "i", "c", "t", "s" }) do
  for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do out[#out + 1] = m.lhs end
end
local ok, cfg = pcall(function() return require("snacks.picker.config").get({}) end)
for _, w in ipairs({ "input", "list", "preview" }) do
  for lhs in pairs(ok and ((cfg.win or {})[w] or {}).keys or {}) do out[#out + 1] = lhs end
end
io.stdout:write(table.concat(out, "\n") .. "\n")
EOF
mkdir -p "$SB/zhome/.local/share/zsh"
if [[ -d "$HOME/.local/share/zsh/plugins" ]]; then
	cp -R "$HOME/.local/share/zsh/plugins" "$SB/zhome/.local/share/zsh/plugins"
fi
HOME="$SB/zhome" REX_HANDOFF=1 ZDOTDIR="$SB/zdot" zsh -i -c 'bindkey -M emacs' \
	>"$SB/t/zsh-keys" 2>/dev/null || true
XDG_CONFIG_HOME="$SB/xdg" XDG_STATE_HOME="$SB/xdg-state" XDG_CACHE_HOME="$SB/xdg-cache" \
	nvim --headless -c "lua vim.defer_fn(function() dofile('$SB/nvim-keys.lua'); \
	vim.cmd('qa!') end, 3000)" >"$SB/t/nvim-keys" 2>&1 || true

cat >"$SB/taken.py" <<'EOF'
import json, re, sys

SHIFTED = dict(zip('~!@#$%^&*()_+{}|:"<>?', "`1234567890-=[]\\;',./"))
NAMES = {"cr": "enter", "return": "enter", "tab": "tab", "space": "space", "bs": "backspace",
         "esc": "escape"}
CLAUDE_DEFAULTS = ["meta+p", "meta+o", "meta+t", "meta+w", "meta+up", "meta+down"]

def canon(mods, key):
    mods = set(mods)
    if len(key) == 1 and key in SHIFTED:
        mods.add("shift")
        key = SHIFTED[key]
    elif len(key) == 1 and key.isupper():
        mods.add("shift")
        key = key.lower()
    return "+".join(sorted(mods) + [key])

def rex_key(k):
    *mods, key = k.lower().split("+")
    return canon({"alt" if m in ("opt", "option", "meta") else m for m in mods}, key)

def ctrl_char(c):
    named = {"?": ("backspace", set()), "@": ("space", {"ctrl"}), "I": ("tab", set()),
             "M": ("enter", set())}
    return named.get(c, (c.lower(), {"ctrl"}))

def zsh_keys(path):
    for line in open(path, encoding="utf-8", errors="replace"):
        m = re.match(r'^"((?:[^"\\]|\\.)*)" (\S+)$', line.strip())
        if not m or m.group(2) in ("self-insert", "undefined-key"):
            continue
        s, mods = m.group(1), set()
        if s.startswith("^["):
            mods.add("alt")
            s = s[2:]
        if len(s) == 2 and s[0] == "^":
            key, extra = ctrl_char(s[1])
            mods |= extra
        elif len(s) == 2 and s[0] == "\\":
            key = s[1]
        elif len(s) == 1:
            key = s
        else:
            continue
        if mods:
            yield "zsh " + m.group(2), canon(mods, key)

def nvim_keys(path):
    for line in open(path, encoding="utf-8", errors="replace"):
        m = re.match(r"^<((?:[MACS]-)+)(.+)>$", line.strip())
        if not m:
            continue
        names = {"M": "alt", "A": "alt", "C": "ctrl", "S": "shift"}
        mods = {names[p] for p in m.group(1).split("-") if p}
        key = m.group(2)
        key = NAMES.get(key.lower(), key) if len(key) > 1 else key
        if "ctrl" in mods and key.isalpha():
            key = key.lower()
        yield "nvim " + line.strip(), canon(mods, key)

def claude_keys(path):
    data = json.load(open(path))
    keys = list(CLAUDE_DEFAULTS)
    for ctx in data.get("bindings", []):
        keys += [k for k, v in ctx.get("bindings", {}).items() if v]
    for k in keys:
        first = k.split(" ")[0]
        if "+" in first:
            yield "claude " + k, rex_key(first)

used = {}
for owner, key in [*zsh_keys(sys.argv[1]), *nvim_keys(sys.argv[2]), *claude_keys(sys.argv[3])]:
    used.setdefault(key, []).append(owner)
data = json.load(sys.stdin)
scratch = {a["name"] for a in data.get("actions", []) if a.get("category") in ("Probe", "Test")}
for b in data["bindings"]:
    if b.get("mode") or b.get("action") in scratch:
        continue
    first = rex_key(b["keys"][0])
    if first == "ctrl+space" and len(b["keys"]) > 1:
        continue
    if first in used or len(b["keys"]) > 1:
        owners = ", ".join(dict.fromkeys(used.get(first, ["a key outside the prefix"])))
        print(">".join(b["keys"]), "takes", owners)
EOF
taken_keys() {
	python3 "$SB/taken.py" "$SB/t/zsh-keys" "$SB/t/nvim-keys" \
		"$REPO/dot_claude/keybindings.json" <<<"$1"
}
taken=$(taken_keys "$keys_json")
[[ -z "$taken" ]] || printf '     %s\n' "$taken"
one_key() { printf '{"bindings":[{"keys":["%s"]}]}' "$1"; }
real_probes() {
	grep -q 'zsh fzf-cd-widget' <<<"$(taken_keys "$(one_key alt+c)")" &&
		grep -q 'nvim <M-J>' <<<"$(taken_keys "$(one_key alt+shift+j)")" &&
		grep -q 'nvim <M-m>' <<<"$(taken_keys "$(one_key alt+m)")" &&
		grep -q 'nvim <M-j>' <<<"$(taken_keys "$(one_key alt+j)")" &&
		grep -q 'claude meta+i' <<<"$(taken_keys "$(one_key alt+i)")"
}
check "the conflict probe reads zsh, Neovim and Claude Code keys" real_probes
check "no Rex key takes a zsh, Neovim or Claude Code key" test -z "$taken"

sends() {
	jq -e --arg k "$1" --arg s "$2" \
		'.bindings[] | select(.keys == ($k | split(">")) and .action == "pane.send_key"
		and .args.key == $s)' <<<"$keys_json" >/dev/null
}
check "ctrl+space ctrl+space sends ctrl+space" sends "ctrl+space>ctrl+space" ctrl+space
for k in w e a s; do
	check "ctrl+shift+$k sends ctrl+alt+$k" sends "ctrl+shift+$k" "ctrl+alt+$k"
done
encodes() {
	local f="$SB/t/enc-$1" b
	b=$(split bash -c "stty raw -echo; exec dd bs=1 count=2 of='$f' 2>/dev/null")
	sleep 0.3
	R send-key -s "$S" -b "$b" "$1" >/dev/null 2>&1
	until5 test -s "$f" && sleep 0.2 && [[ "$(od -An -tx1 "$f" | tr -d ' \n')" == "$2" ]]
}
check "ctrl+alt+w reaches the program as ESC ^W" encodes ctrl+alt+w 1b17

runs_action() {
	jq -e --arg k "$1" --arg a "$2" \
		'.bindings[] | select(.keys == [$k] and .action == $a)' <<<"$keys_json" >/dev/null
}
check "ctrl+enter sends Enter" runs_action ctrl+enter enter_key
check "ctrl+shift+k scrolls a page up" runs_action ctrl+shift+k client.scroll.page_up
check "ctrl+shift+j scrolls a page down" runs_action ctrl+shift+j client.scroll.page_down
check "cmd+pageup scrolls a page up" runs_action cmd+pageup client.scroll.page_up
check "cmd+pagedown scrolls a page down" runs_action cmd+pagedown client.scroll.page_down
entered=$(split bash -c "IFS= read -r l; echo \"got:\$l\" > '$SB/t/entered'; exec sleep 300")
sleep 0.3
R send -s "$S" -b "$entered" hi >/dev/null
R "do" -s "$S" -b "$entered" enter_key >/dev/null 2>&1 || true
check "enter_key ends the typed line with a carriage return" \
	until5 file_has "$SB/t/entered" '^got:hi$'

fg_is() {
	local q
	q=$(jq -cn --arg s "$S" --arg b "$1" \
		'{session_id: $s, block_id: $b, method: "process", args: {}}')
	[[ "$(R api call -s "$S" block.method "$q" | jq -r '.foreground.name')" == "$2" ]]
}
prompt_shows() { grep -qF "$2" <<<"$(R capture -s "$S" -b "$1" 2>/dev/null)"; }
answer_close() {
	local p
	p=$(R "do" -s "$S" --json close_pane "block=$1" 2>/dev/null |
		jq -r '.block_id // empty')
	[[ -n "$p" ]] && until5 prompt_shows "$p" "$2" || return 1
	R send -s "$S" -b "$p" "$3" >/dev/null 2>&1
	until5 gone "$p"
}
confirm_pane=$(split sh -c 'exec sleep 300')
check "the close target runs sleep" until5 fg_is "$confirm_pane" sleep
check "close_pane asks first and keeps the pane on n" \
	answer_close "$confirm_pane" "Close sleep?" n
check "the pane is still open after n" not gone "$confirm_pane"
check "close_pane closes the pane on y" answer_close "$confirm_pane" "Close sleep?" y
check "the pane is closed after y" until5 gone "$confirm_pane"

mkdir -p "$SB/claude-versions" "$SB/claude-bin"
cp /bin/sleep "$SB/claude-versions/2.1.316"
codesign --force -s - "$SB/claude-versions/2.1.316" 2>/dev/null
ln -sf "$SB/claude-versions/2.1.316" "$SB/claude-bin/claude"
agent_pane=$(split "$SB/claude-bin/claude" 300)
check "the fake agent runs its version file" until5 fg_is "$agent_pane" 2.1.316
check "close_pane names the agent, not its version file" \
	answer_close "$agent_pane" "Close claude?" y

mkdir -p "$SB/stub"
cat >"$SB/stub/rex" <<EOF
#!/bin/sh
case "\$*" in
*"client ls --json"*)
	echo '{"clients":[{"client_id":"client:app","info":{"kind":"app"}}]}' ;;
*"-C client:app actions --json"*)
	echo '{"actions":[{"name":"client.tab.goto","title":"Go to Tab"}]}' ;;
*) exec "$(command -v rex)" "\$@" ;;
esac
EOF
chmod +x "$SB/stub/rex"
sheet() {
	strict TERM_PROGRAM=rex REX_SESSION="$S" TMUX= PATH="$SB/stub:$PATH" \
		python3 "$REPO/exact_dot_bin/executable_keys" --plain 2>/dev/null
}
rows=$(sheet)
row_has() { grep -qE "^rex +$1 +$2\$" <<<"$rows"; }
check "the keys sheet lists Rex rows first in Rex" test "$(head -1 <<<"$rows" | cut -c1-4)" = "rex "
check "the keys sheet shows the Lua action title" row_has "root +ctrl\+space > x" "Close Pane"
check "the keys sheet shows the app's title and args" row_has "root +ctrl\+space > 3" \
	"Go to Tab \(3\)"
check "the keys sheet shows readable args" row_has "root +ctrl\+space > shift\+r" \
	"client\.mode\.enter \(resize\)"
check "the keys sheet lists how to leave resize mode" row_has "resize +esc" "client\.mode\.exit"
desc_col() {
	grep -E "^rex +root +$1 " <<<"$rows" | head -1 | awk -v d="$2" '{ print index($0, d) }'
}
check "the keys sheet aligns the passthrough row" test \
	"$(desc_col 'ctrl\+space > ctrl\+space' 'pane.send_key')" = \
	"$(desc_col 'ctrl\+space > x' 'Close Pane')"
check "the keys sheet has no probe or test rows" not grep -qiE '^rex .*(probe|test:)' <<<"$rows"
