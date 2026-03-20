#-----------------------------------------------------------
# @raisedadead's config files
# Copyright: Mrugesh Mohapatra <https://mrugesh.dev>
# License: ISC
#
# File name: env.nu
#-----------------------------------------------------------

$env.LC_CTYPE = "en_US.UTF-8"
$env.LC_ALL = "en_US.UTF-8"
$env.XDG_CONFIG_HOME = ($env.HOME | path join ".config")
$env.RIPGREP_CONFIG_PATH = ($env.XDG_CONFIG_HOME | path join "ripgrep" "config")
$env.STARSHIP_LOG = "error"

$env.HOMEBREW_PREFIX = "/opt/homebrew"
$env.HOMEBREW_CELLAR = "/opt/homebrew/Cellar"
$env.HOMEBREW_REPOSITORY = "/opt/homebrew"

$env.GOPATH = ($env.HOME | path join "go")

$env.EDITOR = "nvim"
$env.VISUAL = "code"
$env.GIT_EDITOR = $env.EDITOR

$env.PATH = (
  $env.PATH
  | split row (char esep)
  | prepend [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
    ($env.HOME | path join ".cargo" "bin")
    ($env.GOPATH | path join "bin")
    "/opt/homebrew/opt/ruby/bin"
    ($env.HOME | path join ".gem" "bin")
    ($env.HOME | path join ".local" "bin")
    ($env.HOME | path join "bin")
    ($env.HOME | path join ".bin")
  ]
  | uniq
)
