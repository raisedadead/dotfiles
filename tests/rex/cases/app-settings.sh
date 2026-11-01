# shellcheck shell=bash
AS="$SB/app-settings"
AS_TMPL=run_onchange_after_rex-defaults.sh.tmpl
AS_JSON=dot_config/rex/themes/custom-themes.json
mkdir -p "$AS/bin"
cat >"$AS/bin/defaults" <<'EOF'
#!/bin/sh
[ -n "$AS_PREFS" ] && [ "$2" = com.superlogical.rex ] || exit 97
cmd=$1
shift 2
exec /usr/bin/defaults "$cmd" "$AS_PREFS" "$@"
EOF
chmod +x "$AS/bin/defaults"

as_source() {
	mkdir -p "$AS/$1/src/dot_config/rex/themes"
	cp "$REPO/$AS_TMPL" "$AS/$1/src/"
	cp "$REPO/$AS_JSON" "$AS/$1/src/$AS_JSON"
}
as_render() {
	chezmoi execute-template --source "$AS/$1/src" <"$AS/$1/src/$AS_TMPL" \
		>"$AS/$1/run.sh" 2>"$AS/$1/render.err"
}
as_run() {
	mkdir -p "$AS/$1/home/.config/rex/themes"
	[[ -e "$AS/$1/home/.config/rex/themes/custom-themes.json" ]] ||
		cp "$AS/$1/src/$AS_JSON" "$AS/$1/home/.config/rex/themes/"
	env HOME="$AS/$1/home" AS_PREFS="$AS/$1/prefs" PATH="$AS/bin:$PATH" \
		bash "$AS/$1/run.sh" >/dev/null 2>"$AS/$1/run.err"
}
as_get() {
	AS_PREFS="$AS/$1/prefs" "$AS/bin/defaults" read com.superlogical.rex "$2" 2>/dev/null
}
as_themes() {
	AS_PREFS="$AS/$1/prefs" "$AS/bin/defaults" export com.superlogical.rex "$AS/$1/out.plist"
	/usr/libexec/PlistBuddy -c 'Print :Workspace.customThemes' "$AS/$1/out.plist"
}
as_seed_themes() {
	AS_PREFS="$AS/$1/prefs" "$AS/bin/defaults" write com.superlogical.rex \
		Workspace.customThemes -data "$(printf %s "$2" | xxd -p | tr -d '\n')"
}

as_kept() {
	local app='{"id":"custom-APP","name":"App Theme"}' seed
	seed=$(jq -c --argjson a "$app" '(.[0].name = "EDITED") + [$a]' "$REPO/$AS_JSON") &&
		as_source keep && as_render keep && as_seed_themes keep "$seed" && as_run keep &&
		as_themes keep | jq -e --slurpfile s "$REPO/$AS_JSON" --argjson a "$app" \
			'. == $s[0] + [$a]' >/dev/null
}
check "app settings keep an app theme and restore a source theme" as_kept

as_dark() {
	as_source drift &&
		jq '.[0].id = "custom-NEW"' "$REPO/$AS_JSON" >"$AS/drift/src/$AS_JSON" &&
		as_render drift && as_run drift &&
		test "$(as_get drift Workspace.darkThemeID)" = custom-NEW
}
check "app settings set darkThemeID from the theme JSON" as_dark

as_badsrc() {
	as_source badsrc && echo '{not json' >"$AS/badsrc/src/$AS_JSON" && not as_render badsrc
}
check "app settings refuse to render a bad theme JSON" as_badsrc

as_refused() {
	! as_run "$1" && ! as_get "$1" Workspace.appearance >/dev/null &&
		grep -q "^rex-defaults: $2" "$AS/$1/run.err"
}
as_bad_dest() {
	as_source "$1" && as_render "$1" && mkdir -p "$AS/$1/home/.config/rex/themes" &&
		printf %s "$2" >"$AS/$1/home/.config/rex/themes/custom-themes.json" &&
		as_refused "$1" "$3"
}
check "app settings stop with a message on a bad theme file" \
	as_bad_dest baddst '{not json' "cannot merge"
check "app settings stop with a message on an empty theme file" \
	as_bad_dest empty '' ".* is empty"
as_bad_app() {
	as_source badapp && as_render badapp && as_seed_themes badapp 'not json' &&
		as_refused badapp "cannot merge .* Workspace.customThemes"
}
check "app settings stop with a message on bad app themes" as_bad_app

as_term_setup() {
	local stub="$AS/term/home/.bin/rex"
	as_source term && as_render term && mkdir -p "$AS/term/home/.bin" &&
		printf '#!/bin/sh\necho "$@" >> %s\n' "$AS/term/rex.args" >"$stub" &&
		chmod +x "$stub" && as_run term &&
		test "$(cat "$AS/term/rex.args")" = "--autostart=false terminfo setup --entry-only"
}
check "app settings install only the xterm-rex entry" as_term_setup
check "app settings make left Option send Alt" \
	test "$(as_get term Workspace.terminalOptionKeyBehavior)" = left
as_no_rex() { as_source norex && as_render norex && as_run norex; }
check "app settings run without the rex CLI" as_no_rex

as_hex() {
	jq -r ".[0].palette.$1"' | "#" + ([.red, .green, .blue] |
		map(. * 255 | round | [(. / 16 | floor), . % 16] |
		map("0123456789abcdef"[.:. + 1]) | add) | add)' "$REPO/$AS_JSON"
}
check "Rex theme ansi 8 is the readable dim grey" test "$(as_hex 'ansi[8]')" = "#7f849c"
