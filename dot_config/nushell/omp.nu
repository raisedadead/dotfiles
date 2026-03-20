# Oh-My-Posh init for nushell

if ($env.config? | is-not-empty) {
    $env.config = ($env.config | upsert render_right_prompt_on_last_line true)
}

$env.POWERLINE_COMMAND = 'oh-my-posh'
$env.POSH_THEME = ($env.HOME | path join ".config" "oh-my-posh" "config.toml")
$env.PROMPT_INDICATOR = ""
$env.POSH_SESSION_ID = (random uuid)
$env.POSH_SHELL = "nu"
$env.POSH_SHELL_VERSION = (version | get version)

$env.VIRTUAL_ENV_DISABLE_PROMPT = 1
$env.PYENV_VIRTUALENV_DISABLE_PROMPT = 1

const _omp_executable = "/opt/homebrew/bin/oh-my-posh"
const _omp_config = "/Users/mrugesh/.config/oh-my-posh/config.toml"

def --wrapped _omp_get_prompt [
    type: string,
    ...args: string
] {
    mut execution_time = -1
    mut no_status = true
    let cmd_dur = ($env.CMD_DURATION_MS? | default '0823')
    if $cmd_dur != '0823' {
        $execution_time = $cmd_dur
        $no_status = false
    }

    (
        ^$_omp_executable print $type
            --save-cache
            --shell=nu
            $"--config=($_omp_config)"
            $"--shell-version=($env.POSH_SHELL_VERSION)"
            $"--status=($env.LAST_EXIT_CODE)"
            $"--no-status=($no_status)"
            $"--execution-time=($execution_time)"
            $"--terminal-width=((term size).columns)"
            $"--job-count=(job list | length)"
            ...$args
    )
}

$env.PROMPT_MULTILINE_INDICATOR = (
    ^$_omp_executable print secondary
        --shell=nu
        $"--config=($_omp_config)"
        $"--shell-version=($env.POSH_SHELL_VERSION)"
)

$env.PROMPT_COMMAND = {||
    mut clear = false
    if $nu.history-enabled {
        let hist = (history | last 1)
        $clear = ($hist | is-empty) or (($hist | get 0?.command? | default "") == "clear")
    }

    if ($env.SET_POSHCONTEXT? | is-not-empty) {
        do --env $env.SET_POSHCONTEXT
    }

    _omp_get_prompt primary $"--cleared=($clear)"
}

$env.PROMPT_COMMAND_RIGHT = {|| _omp_get_prompt right }

^$_omp_executable upgrade --auto
