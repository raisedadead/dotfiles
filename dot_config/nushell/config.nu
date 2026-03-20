#-----------------------------------------------------------
# @raisedadead's config files
# Copyright: Mrugesh Mohapatra <https://mrugesh.dev>
# License: ISC
#
# File name: config.nu
#-----------------------------------------------------------

source catppuccin_mocha.nu

$env.config.show_banner = false
$env.config.edit_mode = "emacs"
$env.config.buffer_editor = "nvim"
$env.config.error_style = "fancy"

$env.config.table = {
  mode: rounded
  index_mode: auto
  show_empty: true
  padding: { left: 1, right: 1 }
  trim: { methodology: wrapping, wrapping_try_keep_words: true }
  header_on_separator: false
  abbreviated_row_count: null
}
$env.config.footer_mode = 25
$env.config.float_precision = 2

$env.config.history = {
  file_format: sqlite
  max_size: 100_000
  sync_on_enter: true
  isolation: false
}

$env.config.completions = {
  quick: true
  partial: true
  algorithm: prefix
  case_sensitive: false
  sort: smart
  external: {
    enable: true
    max_results: 100
    completer: null
  }
}

$env.config.shell_integration = {
  osc2: true
  osc7: true
  osc8: true
  osc9_9: false
  osc133: true
  osc633: false
  reset_application_mode: true
}

$env.config.hooks.pre_prompt = [{||
  if ($env.TMUX? | is-not-empty) {
    let code = ($env.LAST_EXIT_CODE? | default 0)
    ^tmux set-option -qw @last_exit_code $"($code)"
  }
}]

source omp.nu
