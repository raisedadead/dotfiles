#!/usr/bin/env zsh

function which-key() {
  if ! command -v keyb &>/dev/null; then
    print "keyb not found — install via: go install github.com/kencx/keyb@latest"
    return 1
  fi

  local tmpfile="$(mktemp /tmp/keyb-XXXXXX.yml)"
  trap "rm -f '$tmpfile'" EXIT HUP INT TERM

  local -a sections=()
  local -A section_entries=()

  __wk_add() {
    local section="$1" desc="$2" key="$3"
    desc="${desc//\"/\\\"}"
    key="${key//\"/\\\"}"
    local entry="    - name: \"${desc}\"\n      key: \"${key}\""
    if [[ -z "${section_entries[$section]}" ]]; then
      sections+=("$section")
      section_entries[$section]="$entry"
    else
      section_entries[$section]="${section_entries[$section]}\n${entry}"
    fi
  }

  if command -v ghostty &>/dev/null; then
    local _k _a _desc _sec n line
    while IFS= read -r line; do
      line="${line#keybind = }"
      _k="${line%%=*}"; _a="${line#*=}"

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
      _k="${_k//+/ + }"

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
        scroll_page_lines:*)   n="${_a#scroll_page_lines:}"
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

      case "$_a" in
        *split*|close_surface)                                                    _sec="Ghostty Splits" ;;
        *tab*|last_tab)                                                           _sec="Ghostty Tabs" ;;
        scroll_*|jump_to_prompt:*)                                                _sec="Ghostty Scroll" ;;
        *clipboard*|paste_*|copy_*|select_all)                                    _sec="Ghostty Clipboard" ;;
        *window*|toggle_fullscreen|toggle_quick_terminal|toggle_command_palette)   _sec="Ghostty Window" ;;
        *font_size*)                                                              _sec="Ghostty Font" ;;
        adjust_selection:*)                                                       _sec="Ghostty Selection" ;;
        text:*|esc:*)                                                             _sec="Ghostty Input" ;;
        *)                                                                        _sec="Ghostty Other" ;;
      esac

      __wk_add "$_sec" "$_desc" "$_k"
    done < <(ghostty +list-keybinds 2>/dev/null)
  fi

  local _seq _wid _rk _sec line
  while IFS= read -r line; do
    [[ "$line" == *'"-"'* ]] && continue
    [[ "$line" == '"\M'* ]] && continue

    _seq="${line#\"}"; _wid="${_seq#*\" }"; _seq="${_seq%%\"*}"

    case "$_wid" in
      self-insert*|digit-argument|neg-argument|undefined-key|bracketed-paste) continue ;;
    esac
    [[ "$_seq" == '^[O'? ]] && continue

    case "$_seq" in
      '^[[A')    _rk="Up" ;;
      '^[[B')    _rk="Down" ;;
      '^[[C')    _rk="Right" ;;
      '^[[D')    _rk="Left" ;;
      '^[[1;3C') _rk="Opt+Right" ;;
      '^[[1;3D') _rk="Opt+Left" ;;
      '^?')      _rk="Backspace" ;;
      '^[''^H'|'^[''^?') _rk="Alt+Backspace" ;;
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

    case "$_wid" in
      *-char|*-word|beginning-of-*|end-of-*|vi-goto-column)                                                _sec="ZSH Movement" ;;
      *history*|*search*)                                                                                   _sec="ZSH History" ;;
      kill-*|*-kill-*|yank*|delete-*|*-delete-*|transpose-*|*-case-word|copy-*|quoted-insert|overwrite-mode) _sec="ZSH Editing" ;;
      expand-*|*complet*|list-*)                                                                            _sec="ZSH Completion" ;;
      *)                                                                                                    _sec="ZSH Other" ;;
    esac

    __wk_add "$_sec" "$_wid" "$_rk"
  done < <(bindkey)

  __wk_add "Shell Utilities" "Which-key (this menu)" "Ctrl+/"
  __wk_add "Shell Utilities" "SSH host selector" "Ctrl+Z"

  __wk_add "FZF" "File search" "Ctrl+T"
  __wk_add "FZF" "Directory navigation (cd)" "Alt+C"
  __wk_add "FZF" "Navigate results down/up" "Ctrl+J / Ctrl+K"
  __wk_add "FZF" "Toggle preview" "Ctrl+/"
  __wk_add "FZF" "Copy selection to clipboard" "Ctrl+Y"
  __wk_add "FZF" "Scroll preview" "Shift+Up/Down"

  __wk_add "Atuin (vim-normal)" "Open history search" "Ctrl+R"
  __wk_add "Atuin (vim-normal)" "Navigate down/up" "J / K"
  __wk_add "Atuin (vim-normal)" "Insert mode (filter)" "I"
  __wk_add "Atuin (vim-normal)" "Normal mode" "Esc"
  __wk_add "Atuin (vim-normal)" "Select" "Enter"
  __wk_add "Atuin (vim-normal)" "Return to shell to edit" "Tab"

  {
    local s
    for s in "${sections[@]}"; do
      print -- "- name: \"${s}\""
      print "  keybinds:"
      print "${section_entries[$s]}"
    done
  } > "$tmpfile"

  keyb -k "$tmpfile" -c "${XDG_CONFIG_HOME:-$HOME/.config}/keyb/config.yml"

  unfunction __wk_add 2>/dev/null
}
