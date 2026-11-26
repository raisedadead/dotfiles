# shellcheck shell=bash
# shellcheck disable=SC2154
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
mkdir -p "$SB/zhome/.local/share/zsh" "$SB/zhome/.cache/fsh"
: >"$SB/zhome/.cache/fsh/secondary_theme.zsh"
zplug="$SB/zhome/.local/share/zsh/plugins"
if [[ -d "$HOME/.local/share/zsh/plugins" ]]; then
	cp -R "$HOME/.local/share/zsh/plugins" "$zplug"
fi
lock="$REPO/dot_config/exact_zsh/plugins.lock"
pnpm_rev=$(awk '$1 ~ /\/pnpm-shell-completion$/ { print $2 }' "$lock")
plug_dir() { test -d "$zplug"; }
plug_stamp() { cmp -s "$zplug/.plugins.lock" "$lock"; }
pnpm_stamp() { test "$(cat "$zplug/.pnpm-helper-revision" 2>/dev/null)" = "$pnpm_rev"; }
check "the zsh plugins folder exists" plug_dir
check "the zsh plugin stamp matches the branch lock" plug_stamp
check "the pnpm helper stamp matches the branch lock" pnpm_stamp
if plug_dir && plug_stamp && pnpm_stamp; then
	HOME="$SB/zhome" ZDOTDIR="$SB/zdot" zsh -i -c 'bindkey -M emacs' \
		>"$SB/t/zsh-keys" 2>/dev/null || true
fi
XDG_CONFIG_HOME="$SB/xdg" XDG_STATE_HOME="$SB/xdg-state" XDG_CACHE_HOME="$SB/xdg-cache" \
	nvim --headless -c "lua vim.defer_fn(function() dofile('$SB/nvim-keys.lua'); \
	vim.cmd('qa!') end, 3000)" >"$SB/t/nvim-keys" 2>&1 || true

cat >"$SB/taken.py" <<'EOF'
import json, re, sys

SHIFTED = dict(zip('~!@#$%^&*()_+{}|:"<>?', "`1234567890-=[]\\;',./"))
NAMES = {"cr": "enter", "return": "enter", "tab": "tab", "space": "space", "bs": "backspace",
         "esc": "escape"}
CLAUDE_DEFAULTS = ["meta+p", "meta+o", "meta+t", "meta+w", "meta+up", "meta+down"]
ALLOWED = {
    "zsh run-help", "zsh down-case-word", "zsh self-insert-unmeta", "zsh _bash_complete-word",
    "zsh get-line", "zsh spell-word", "zsh accept-and-hold", "zsh which-command",
    "claude meta+o", "nvim <M-h>", "nvim <M-r>",
}

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
    if len(b["keys"]) == 1 and set(used.get(first, ["-"])) <= ALLOWED:
        continue
    if first in used or len(b["keys"]) > 1:
        owners = ", ".join(dict.fromkeys(used.get(first, ["a key outside the prefix"])))
        print(">".join(b["keys"]), "takes", owners)
EOF
taken_keys() {
	python3 "$SB/taken.py" "$SB/t/zsh-keys" "$SB/t/nvim-keys" \
		"$DOTCLAUDE/keybindings.json" <<<"$1"
}
taken=$(taken_keys "$keys_json")
[[ -z "$taken" ]] || printf '     %s\n' "$taken"
one_key() { printf '{"bindings":[{"keys":["%s"]}]}' "$1"; }
real_probes() {
	grep -q 'zsh fzf-cd-widget' <<<"$(taken_keys "$(one_key alt+c)")" &&
		grep -q 'nvim <M-C-W>' <<<"$(taken_keys "$(one_key ctrl+alt+w)")" &&
		grep -q 'nvim <M-m>' <<<"$(taken_keys "$(one_key alt+m)")" &&
		grep -q 'claude meta+i' <<<"$(taken_keys "$(one_key alt+i)")"
}
check "the conflict probe reads zsh, Neovim and Claude Code keys" real_probes
check "no Rex key takes a zsh, Neovim or Claude Code key" test -z "$taken"

sends() {
	jq -e --arg k "$1" --arg s "$2" \
		'.bindings[] | select(.keys == ($k | split(">")) and .action == "pane.send_key"
		and .args.key == $s)' <<<"$keys_json" >/dev/null
}
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
user_binds() {
	jq -e --arg k "$1" '.bindings[] | select(.keys == [$k] and ((.source // "") | test("\\.lua:")))' \
		<<<"$keys_json" >/dev/null
}
check "the user-bind probe sees a user bind" user_binds alt+o
check "ctrl+enter goes to the program" not user_binds ctrl+enter
no_leader() { ! jq -e '.bindings[] | select(.keys[0] == "ctrl+space")' <<<"$keys_json" >/dev/null; }
check "no Rex key starts with ctrl+space" no_leader
check "the config binds no key in a mode" \
	not jq -e '.bindings[] | select(.mode and ((.source // "") | test("\\.lua:")))' <<<"$keys_json"
entered=$(split bash -c "IFS= read -r l; echo \"got:\$l\" > '$SB/t/entered'; exec sleep 300")
sleep 0.3
R send -s "$S" -b "$entered" hi >/dev/null
R "do" -s "$S" -b "$entered" enter_key >/dev/null 2>&1 || true
check "enter_key ends the typed line with a carriage return" \
	until5 file_has "$SB/t/entered" '^got:hi$'

sheet() {
	strict TERM_PROGRAM=rex REX_BLOCK="$plain" TMUX= \
		python3 "$REPO/exact_dot_bin/executable_keys" --plain 2>/dev/null
}
check "the keys sheet lists no Rex rows, also in Rex" not grep -q '^rex ' <<<"$(sheet)"
