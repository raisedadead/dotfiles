#!/usr/bin/env zsh

function which-key() {
  local filter="${1:-}"
  local bold=$'\e[1m' dim=$'\e[2m' reset=$'\e[0m'
  local cyan=$'\e[36m' yellow=$'\e[33m' blue=$'\e[34m'
  local div="${dim}│${reset}"
  local -a out=()

  __wk_head() { out+=("" "${bold}${cyan}  $1${reset}") }
  __wk_row()  { out+=("$(printf "    ${yellow}%-26s${reset} ${div} %s" "$1" "$2")") }
  __wk_cat()  {
    local label="$1"; shift
    (( $# )) || return
    __wk_head "$label"
    local p; for p in "$@"; do __wk_row "${p%%	*}" "${p#*	}"; done
  }

  # ── Ghostty (live from ghostty +list-keybinds) ─────────
  if command -v ghostty &>/dev/null; then
    local -a gs=() gt=() gsc=() gc=() gw=() gf=() gse=() gi=() gm=()
    local _k _a _desc

    while IFS= read -r line; do
      line="${line#keybind = }"
      _k="${line%%=*}"; _a="${line#*=}"

      # Translate key names
      _k="${_k//super/Cmd}"; _k="${_k//alt/Opt}"
      _k="${_k//ctrl/Ctrl}"; _k="${_k//shift/Shift}"
      _k="${_k//arrow_left/←}"; _k="${_k//arrow_right/→}"
      _k="${_k//arrow_up/↑}"; _k="${_k//arrow_down/↓}"
      _k="${_k//page_up/PgUp}"; _k="${_k//page_down/PgDn}"
      _k="${_k//backquote/\`}"; _k="${_k//grave_accent/\`}"
      _k="${_k//bracket_left/[}"; _k="${_k//bracket_right/]}"
      _k="${_k//enter/Enter}"; _k="${_k//tab/Tab}"; _k="${_k//backspace/⌫}"
      _k="${_k//equal/=}"; _k="${_k//home/Home}"; _k="${_k//end/End}"
      _k="${_k//digit_/}"

      # Translate action
      case "$_a" in
        goto_split:*)          _desc="Go to ${_a#goto_split:}" ;;
        new_split:*)           _desc="New ${_a#new_split:}" ;;
        resize_split:*)        _desc="Resize ${${_a#resize_split:}%%,*}" ;;
        equalize_splits)       _desc="Equalize" ;;
        toggle_split_zoom)     _desc="Toggle zoom" ;;
        close_surface)         _desc="Close pane" ;;
        goto_tab:*)            _desc="Go to ${_a#goto_tab:}" ;;
        new_tab)               _desc="New" ;;
        next_tab)              _desc="Next" ;;
        previous_tab)          _desc="Previous" ;;
        close_tab*)            _desc="Close" ;;
        last_tab)              _desc="Last" ;;
        scroll_page_up)        _desc="Page up" ;;
        scroll_page_down)      _desc="Page down" ;;
        scroll_page_lines:*)   local n="${_a#scroll_page_lines:}"
                               [[ "$n" == -* ]] && _desc="Up ${n#-} lines" || _desc="Down $n lines" ;;
        scroll_to_top)         _desc="To top" ;;
        scroll_to_bottom)      _desc="To bottom" ;;
        jump_to_prompt:1)      _desc="Next prompt" ;;
        jump_to_prompt:-1)     _desc="Prev prompt" ;;
        copy_to_clipboard)     _desc="Copy" ;;
        paste_from_clipboard)  _desc="Paste" ;;
        paste_from_selection)  _desc="Paste selection" ;;
        copy_url_to_clipboard) _desc="Copy URL" ;;
        select_all)            _desc="Select all" ;;
        adjust_selection:*)    _desc="Select ${_a#adjust_selection:}" ;;
        new_window)            _desc="New window" ;;
        close_window)          _desc="Close window" ;;
        close_all_windows)     _desc="Close all" ;;
        toggle_fullscreen)     _desc="Fullscreen" ;;
        toggle_quick_terminal) _desc="Quick terminal" ;;
        toggle_command_palette) _desc="Command palette" ;;
        increase_font_size*)   _desc="Increase" ;;
        decrease_font_size*)   _desc="Decrease" ;;
        reset_font_size)       _desc="Reset" ;;
        open_config)           _desc="Open config" ;;
        reload_config)         _desc="Reload config" ;;
        clear_screen)          _desc="Clear screen" ;;
        undo)                  _desc="Undo" ;;
        redo)                  _desc="Redo" ;;
        write_scrollback_file:*) _desc="Scrollback → ${_a#write_scrollback_file:}" ;;
        write_screen_file:*)   _desc="Screen → ${_a#write_screen_file:}" ;;
        inspector:toggle)      _desc="Inspector" ;;
        text:*)                _desc="Send ${_a#text:}" ;;
        esc:*)                 _desc="Send Esc+${_a#esc:}" ;;
        *)                     _desc="${_a//_/ }" ;;
      esac

      local pair="${_k}	${_desc}"
      case "$_a" in
        *split*|close_surface)                                                    gs+=("$pair") ;;
        *tab*|last_tab)                                                           gt+=("$pair") ;;
        scroll_*|jump_to_prompt:*)                                                gsc+=("$pair") ;;
        *clipboard*|paste_*|copy_*|select_all)                                    gc+=("$pair") ;;
        *window*|toggle_fullscreen|toggle_quick_terminal|toggle_command_palette)   gw+=("$pair") ;;
        *font_size*)                                                              gf+=("$pair") ;;
        adjust_selection:*)                                                       gse+=("$pair") ;;
        text:*|esc:*)                                                             gi+=("$pair") ;;
        *)                                                                        gm+=("$pair") ;;
      esac
    done < <(ghostty +list-keybinds 2>/dev/null)

    __wk_cat "Ghostty: Splits"    "${gs[@]}"
    __wk_cat "Ghostty: Tabs"      "${gt[@]}"
    __wk_cat "Ghostty: Scroll"    "${gsc[@]}"
    __wk_cat "Ghostty: Clipboard" "${gc[@]}"
    __wk_cat "Ghostty: Window"    "${gw[@]}"
    __wk_cat "Ghostty: Font"      "${gf[@]}"
    __wk_cat "Ghostty: Selection" "${gse[@]}"
    __wk_cat "Ghostty: Input"     "${gi[@]}"
    __wk_cat "Ghostty: Other"     "${gm[@]}"
  fi

  # ── ZSH (live from bindkey) ────────────────────────────
  local -a zm=() zh=() ze=() zco=() zo=()
  local _seq _wid _rk

  while IFS= read -r line; do
    [[ "$line" == *'"-"'* ]] && continue
    [[ "$line" == '"\M'* ]] && continue

    _seq="${line#\"}"; _wid="${_seq#*\" }"; _seq="${_seq%%\"*}"

    case "$_wid" in
      self-insert*|digit-argument|neg-argument|undefined-key|bracketed-paste) continue ;;
    esac
    [[ "$_seq" == '^[O'? ]] && continue

    # Translate key sequence
    case "$_seq" in
      '^[[A')    _rk="Up" ;;
      '^[[B')    _rk="Down" ;;
      '^[[C')    _rk="Right" ;;
      '^[[D')    _rk="Left" ;;
      '^[[1;3C') _rk="Opt+Right" ;;
      '^[[1;3D') _rk="Opt+Left" ;;
      '^?')      _rk="Backspace" ;;
      '^[''^H'|'^[''^?') _rk="Alt+Backspace" ;;
      '^['^?)    # Alt+Ctrl combos
                 _rk="Alt+Ctrl+${_seq#'^['^}" ;;
      '^['?)     _rk="Alt+${(U)_seq[-1]}" ;;
      '^['*)     _rk="Esc+${_seq#'^['}" ;;
      '^X'^?)    _rk="Ctrl+X Ctrl+${_seq[-1]}" ;;
      '^X'?)     _rk="Ctrl+X ${_seq[-1]}" ;;
      '^@')      _rk="Ctrl+Space" ;;
      '^I')      _rk="Tab" ;;
      '^M')      _rk="Enter" ;;
      '^'?)      _rk="Ctrl+${_seq[-1]}" ;;
      ?)         _rk="$_seq" ;;
      *)         _rk="$_seq" ;;
    esac

    local pair="${_rk}	${_wid}"
    case "$_wid" in
      *-char|*-word|beginning-of-*|end-of-*|vi-goto-column)                                                zm+=("$pair") ;;
      *history*|*search*)                                                                                   zh+=("$pair") ;;
      kill-*|*-kill-*|yank*|delete-*|*-delete-*|transpose-*|*-case-word|copy-*|quoted-insert|overwrite-mode) ze+=("$pair") ;;
      expand-*|*complet*|list-*)                                                                            zco+=("$pair") ;;
      *)                                                                                                    zo+=("$pair") ;;
    esac
  done < <(bindkey)

  __wk_cat "ZSH: Movement"   "${zm[@]}"
  __wk_cat "ZSH: History"    "${zh[@]}"
  __wk_cat "ZSH: Editing"    "${ze[@]}"
  __wk_cat "ZSH: Completion" "${zco[@]}"
  __wk_cat "ZSH: Other"      "${zo[@]}"

  # ── FZF (static) ───────────────────────────────────────
  __wk_head "FZF"
  __wk_row "Ctrl+T"           "File search"
  __wk_row "Alt+C"            "Directory navigation (cd)"
  __wk_row "Ctrl+J / Ctrl+K"  "Navigate results down/up"
  __wk_row "Ctrl+/"           "Toggle preview"
  __wk_row "Ctrl+Y"           "Copy selection to clipboard"
  __wk_row "Shift+Up/Down"    "Scroll preview"

  # ── Atuin (static) ─────────────────────────────────────
  __wk_head "Atuin (vim-normal)"
  __wk_row "Ctrl+R"           "Open history search"
  __wk_row "J / K"            "Navigate down/up"
  __wk_row "I"                "Insert mode (filter)"
  __wk_row "Esc"              "Normal mode"
  __wk_row "Enter"            "Select"
  __wk_row "Tab"              "Return to shell to edit"

  # ── Output ─────────────────────────────────────────────
  if [[ -n "$filter" ]]; then
    local -a filtered=()
    local pending_head="" section_matched=false
    local fl="${(L)filter}" line
    for line in "${out[@]}"; do
      if [[ "$line" == *$'\e[36m'* ]]; then
        pending_head="$line"
        section_matched=false
        [[ "${(L)line}" == *"$fl"* ]] && section_matched=true
      elif [[ -z "$line" ]]; then
        continue
      elif $section_matched; then
        [[ -n "$pending_head" ]] && { filtered+=("" "$pending_head"); pending_head=""; }
        filtered+=("$line")
      elif [[ "${(L)line}" == *"$fl"* ]]; then
        [[ -n "$pending_head" ]] && { filtered+=("" "$pending_head"); pending_head=""; }
        filtered+=("$line")
      fi
    done
    local output="${(F)filtered}"
  else
    local output="${(F)out}"
  fi
  if [[ -t 1 ]]; then
    printf '%s\n' "$output" | less -R
  else
    printf '%s\n' "$output"
  fi

  unfunction __wk_head __wk_row __wk_cat 2>/dev/null
}
