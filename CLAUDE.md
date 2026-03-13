# Dotfiles

Managed by [homesick](https://github.com/technicalpickles/homesick). Files in `home/` are symlinked to `~` via `homesick link dotfiles`.

## Structure

```
home/
├── .bin/              # Shell scripts (sourced by .zshrc via functions.sh)
│   ├── functions.sh   # Entry point — sources utils, cleanup, commit-past, ssh-helpers, search, keybindings
│   ├── keybindings.sh # Registers C-f (yazi) and SSH host-select zle widgets
│   ├── search.sh      # rgs (ripgrep+fzf) and fds (fd+fzf) helpers
│   └── utils.sh       # OS detection, tool checker, set_default_app
├── .config/
│   ├── tmux/
│   │   ├── tmux.conf    # Core config — prefix, options, plugins (TPM)
│   │   ├── keybinds.conf # All keybindings (must sync with keyb.yml)
│   │   ├── theme.conf   # Status bar three-zone layout
│   │   ├── scripts/     # Popup helpers: sesh-popup, keyb-popup, command-palette, new-session-popup
│   │   └── plugins/     # TPM plugins (gitignored)
│   ├── ghostty/
│   │   ├── config       # Terminal config (Catppuccin Mocha, Berkeley Mono)
│   │   └── shaders/     # Custom GLSL shaders (cursor_warp.glsl)
│   ├── keyb/            # Keybinding cheatsheet (keyb.yml + config.yml)
│   ├── sesh/            # Session manager config (sesh.toml)
│   ├── yazi/            # File manager config (yazi.toml, keymap.toml, plugins)
│   └── oh-my-posh/      # Prompt theme (config.toml, Catppuccin Mocha palette)
├── .zshrc               # Main shell config
├── .zshenv              # Environment variables (PATH, editor cache, rbenv lazy-load)
├── .zprofile            # Login shell setup
├── .alias.zshrc         # Aliases
├── .gitconfig           # Git config
└── .fzf.zshrc           # fzf integration (Catppuccin theme, fd commands)
```

## Homesick Linking

- `homesick link dotfiles` symlinks **individual files**, not directories
- New files in `.bin/` or `.config/` need manual symlinks: `ln -s ../.homesick/repos/dotfiles/home/.bin/foo.sh ~/.bin/foo.sh`
- New directories under `.config/` (e.g., `keyb/`) also need manual symlinks for their contents
- Separate repo `dotfiles-nvim` handles neovim config
- Separate repo `dotfiles-private` handles private/machine-specific files
- Separate repo `dotfiles-macos` handles macOS-specific config

## Tmux

Prefix: `Ctrl+Space` (rebound from default `Ctrl+b`).

Plugins (via TPM): tmux-yank, tmux-fzf-url.

Terminal features enabled for ghostty: RGB, hyperlinks, clipboard, extended-keys.

### Neovim Integration

- `C-M-h/j/k/l` navigates tmux panes **or** forwards to neovim via `@pane-is-vim` user option
- Requires `smart-splits.nvim` in neovim to set `@pane-is-vim` on the pane
- Same bindings work in copy-mode-vi for pane switching while selecting
- Prefix `h/j/k/l` available as fallback pane navigation

### Keybinding System

- keybinds.conf and keyb.yml must stay in sync — always update both when changing bindings
- tmux names Shift-Tab as `BTab` (e.g., `M-BTab`), not `M-S-Tab`
- `M-` (Alt) prefix-free bindings for navigation/splits/windows/sessions/popups
- `C-M-h/j/k/l` for pane navigation (with neovim forwarding)
- Prefix `H/J/K/L` for pane resize (repeatable)
- Prefix `Space` opens which-key style `display-menu` showing all prefix bindings
- zsh: emacs mode default (`bindkey -e`) with `C-z` toggle to vi mode — required for Alt keybinds to work without lag
- Vi mode indicator: prompt chevron flips `❯` → `❮` and turns mauve; requires `_omp_get_prompt` re-eval in `zle-keymap-select`
- All keybindings documented in `home/.config/keyb/keyb.yml`, viewable via `M-?` in tmux
- Popup scripts live in `home/.config/tmux/scripts/`, not `.bin/`

### Popup Conventions

All tmux popups follow consistent styling:

- Size: 70%x80% (lazygit), 53%x60% (fzf-tmux pickers), 40%x45% (command palette), 20%x5 (new session)
- Border: rounded, white color
- fzf color scheme: `header:8,pointer:yellow,prompt:yellow,border:white,label:yellow`
- Active category indicator: bright yellow text, inactive: dim (brightblack)
- Tab/Shift-Tab cycles categories in sesh-popup (5 categories) and keyb-popup (8 categories)
- Scripts use `fzf-tmux -p` for popups (not `display-popup` + `fzf`) except lazygit

### Status Bar

- theme.conf header comments document the three-zone layout — update when changing indicator logic
- Three-zone status bar via `status-format[0]` with `#[align=left|centre|right]`
- Left: window dots — yellow (active), brightyellow (bell), red (error), blue (activity), brightblack (idle); pane superscript when > 1
- Centre: `❮ session // windows ❯` — session in magenta, active window in cyan, inactive dimmed; zoom shows `←`, prefix shows `◆` (yellow)
- Right: session squares — green (attached), brightblack (other); superscript window count when > 1
- Exit code tracking via `_tmux_exit_code` precmd hook in `.zshrc` — must be first in precmd queue to capture `$?` before OMP modifies it

## Ghostty

- Theme: Catppuccin Mocha, font: Berkeley Mono (size 14, thickened, calt+ss01+zero features)
- Nerd Font symbols via codepoint map (U+E000–U+F8FF, U+F0000–U+FFFFF)
- Background: 80% opacity, 15px blur
- `macos-option-as-alt = left` — required for Alt keybinds in tmux/zsh
- Shell integration: cursor + sudo only (not command_status — exit codes handled by zsh precmd)
- Custom shader: `shaders/cursor_warp.glsl`
- Key bindings: `Shift+Enter` = literal `\n`, `Ctrl+Enter` = literal `\r`
- Scrollback nav: `Ctrl+Shift+J/K` (5 lines), `Ctrl+Shift+H/L` (top/bottom)
- Quick terminal: `Ctrl+`` (global toggle, 50%x50%, centered)

## Yazi

File manager with plugin ecosystem. Opened via `C-f` zle widget in zsh (registered in keybindings.sh). The `y()` wrapper in functions.sh handles cd-on-exit.

Key conventions:

- `Enter` = smart-enter (open dirs, files in $EDITOR)
- `L/H` = bypass (skip single-child directories)
- `q` = quit without cd, `Q` = quit with cd
- `T` = toggle preview, `F` = smart filter, `C-f` = jump-to-char
- `g,r` = git root, `g,d` = Downloads, `g,D` = DEV, `g,.` = dotfiles
- Plugins: smart-enter, bypass, jump-to-char, smart-filter, toggle-pane, full-border, git, relative-motions, folder-rules

## Sesh

Session manager. Sort order: tmux → config → zoxide.

- Project wildcards: `~/DEV/fCC/*`, `~/DEV/rd/*`, `~/DEV/one-off/*`
- Named sessions: dotfiles, dotfiles-nvim, dotfiles-private, dotfiles-macos, dotfiles-ai-tools (homesick castles)
- Preview: eza with git/icons, `dir_length = 2` for display names

## FZF

- Theme: Catppuccin Mocha (defined in `.fzf.zshrc`)
- File search: `fd --follow --hidden --exclude .git --exclude node_modules --exclude .venv --no-ignore-vcs`
- `Ctrl+T`: file picker (bat preview, 70% height)
- `Alt+C`: directory picker (eza tree preview, 70% height)
- `Ctrl+R`: NOT used — atuin handles history search (initialized with `--disable-up-arrow`)
- fzf-tab: loaded in zinit wait stage 0a for completion menu

## zshrc Load Order

- `zsh-defer` is NOT available until after zinit loads it — don't use in the prompt section
- OMP init is cached via `~/.cache/zsh-eval-cache/oh-my-posh.zsh` with binary+config mtime invalidation
- `_omp_kill_bootstrap` prevents re-sourcing 344-line OMP init on every prompt
- OMP spawns 3 subprocesses per startup: init (~30ms), secondary prompt (~18ms), primary prompt (~43ms)
- `cached_evalz` invalidates on binary mtime only; OMP needs config mtime check too (custom cache logic)
- Zinit plugin load stages: 0a (fzf-tab), 1a (syntax), 1b (suggestions), 1c (smartinput), 1d (pnpm), 2a (touchplus), 2b (wakatime)
- Deferred tool inits: direnv, gh, op, but, wrangler, wt, sesh completions (all via `cached_evalz`)

## Cross-Tool Integration

- **tmux ↔ neovim**: Seamless pane nav via smart-splits.nvim (`@pane-is-vim` option on pane)
- **tmux ↔ zsh**: `_tmux_exit_code` precmd hook writes `@last_exit_code` window option for status bar error indicator
- **tmux ↔ ghostty**: Terminal features (hyperlinks, clipboard, extkeys) enabled in tmux.conf; `macos-option-as-alt` enables Alt binds
- **zsh ↔ ghostty**: Shell integration (cursor, sudo); OMP prompt renders vi-mode indicator
- **zsh ↔ fzf**: Ctrl+T/Alt+C pickers from .fzf.zshrc; fzf-tab for completions
- **zsh ↔ atuin**: Replaces Ctrl+R history; `--disable-up-arrow` flag
- **zsh ↔ yazi**: `C-f` widget opens yazi; `y()` wrapper handles cd-on-exit via temp cwd file

## Validation

- Shell scripts: `shellcheck` (advisory — doesn't support zsh, SC1071 expected)
- Ghostty config: `ghostty +show-config` to verify parsing
- tmux config: `tmux source-file` to verify loading
- YAML: `python3 -c "import yaml; yaml.safe_load(open('file'))"`
