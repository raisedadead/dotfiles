# shellcheck shell=bash
CC="$SB/config-check"
CC_TMPL=run_onchange_before_rex-config-check.sh.tmpl

cc_src() {
	mkdir -p "$CC/$1/src/dot_config/rex" "$CC/$1/home/.bin"
	cp "$SRC"/*.lua "$CC/$1/src/dot_config/rex/"
}
cc_render() {
	chezmoi execute-template --source "$CC/$1/src" <"$REPO/$CC_TMPL" >"$CC/$1/run.sh"
}
cc_run() {
	[[ -n "${2:-}" ]] || ln -sf "$SB/guard/rex" "$CC/$1/home/.bin/rex"
	env HOME="$CC/$1/home" bash "$CC/$1/run.sh" >"$CC/$1/out" 2>&1
}

cc_src clean && cc_render clean
check "the apply check passes a clean Rex config" cc_run clean
cc_src broken
echo 'local x =' >>"$CC/broken/src/dot_config/rex/keys.lua"
cc_render broken
check "the apply check stops on a broken Rex module" not cc_run broken
check "the apply check names the error" grep -q 'keys.lua.*syntax error' "$CC/broken/out"
cc_src norex && cc_render norex
check "the apply check passes when the rex CLI is absent" cc_run norex none
cc_src changed && cc_render changed
mv "$CC/changed/run.sh" "$CC/changed/before.sh"
echo '-- x' >>"$CC/changed/src/dot_config/rex/popups.lua"
cc_render changed
check "a changed module changes the apply check" \
	not cmp -s "$CC/changed/before.sh" "$CC/changed/run.sh"
