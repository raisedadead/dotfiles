# nvim

[LazyVim](https://github.com/LazyVim/LazyVim) with a thin override layer. LazyVim owns the defaults; this directory only carries what it does not do, or does differently from what this rig needs. Requires Neovim 0.11+, a Nerd Font, and `tree-sitter-cli`.

## Structure

```
nvim/
├── init.lua                    # requires config.lazy
├── lazyvim.json                # enabled LazyVim extras (:LazyExtras writes this)
├── lazy-lock.json              # plugin pins — chezmoi-tracked, see Updating
└── lua/
    ├── config/
    │   ├── lazy.lua            # lazy.nvim bootstrap + LazyVim import
    │   ├── options.lua         # deltas vs LazyVim defaults
    │   ├── keymaps.lua         # keymaps LazyVim does not set
    │   └── autocmds.lua        # formatoptions fix
    └── plugins/
        ├── colorscheme.lua     # catppuccin mocha, transparent
        ├── smart-splits.lua    # tmux ↔ nvim pane navigation
        ├── chezmoi.lua         # edit/apply dotfiles source in place
        └── conform.lua         # trailing-whitespace fallback formatter
```

## Overrides, and why

| Override                          | LazyVim default   | Reason                                      |
| --------------------------------- | ----------------- | ------------------------------------------- |
| `scrolloff = 8`                   | `4`               | taste                                       |
| `inccommand = "split"`            | `"nosplit"`       | preview `:s` results in a split             |
| `breakindent`                     | unset             | LazyVim force-wraps text/markdown/gitcommit |
| custom `listchars`                | nvim default      | `» · ␣` over `> - +`                        |
| `jk` → `<Esc>`                    | unmapped          | muscle memory                               |
| `<C-d>`/`<C-u>` + `zz`            | unmapped          | keep the cursor centred                     |
| `formatoptions:remove{o,r}`       | global `jcroqlnt` | stop comment leaders auto-continuing        |
| conform `["_"] = trim_whitespace` | none              | autoformat covers only real formatters      |
| catppuccin mocha, transparent     | tokyonight        | pairs with Ghostty's background opacity     |
| `checker.enabled = false`         | `true`            | `lazy-lock.json` is chezmoi-tracked         |

## Cross-tool integration

- **tmux**: `smart-splits.nvim` sets the tmux user option `@pane-is-vim`; `keybinds.conf` branches on it so `M-H/J/K/L` navigates nvim splits inside a vim pane and tmux panes everywhere else. Same arbitration routes the `Ctrl+Shift W/E/A/S` rewrites. Dropping this plugin silently degrades both to tmux-pane-only.
- **chezmoi**: `chezmoi.nvim` watches `~/.dotfiles/*` so source edits apply on write.

## Keymaps

LazyVim's own — `<leader>` is `Space`, `<leader>?` lists buffer-local maps, and `keys` (the tmux `M-?` cheatsheet) reads them live from nvim. Two traps worth remembering: `<leader>fg` is **git files**, grep is `<leader>sg` or `<leader>/`; `<leader>e` comes from the `editor.snacks_explorer` extra, not from core.

## Updating

`checker` is off by design. Update deliberately:

```sh
nvim --headless "+Lazy! update" +qa   # or :Lazy update in a session
home re-add                            # capture the new lazy-lock.json
```

Never `:Lazy sync` — it uninstalls anything missing from the current spec.
