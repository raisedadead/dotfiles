# nvim

[LazyVim](https://github.com/LazyVim/LazyVim) with a thin override layer. LazyVim owns the defaults; this directory only carries what it does not do, or does differently from what this rig needs. Requires Neovim 0.11.2+ (LazyVim's own health check tests `nvim-0.11.2`), a Nerd Font, and `tree-sitter-cli`.

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
    │   └── autocmds.lua        # formatoptions fix, trim-on-save
    └── plugins/
        ├── colorscheme.lua     # catppuccin mocha, transparent
        ├── smart-splits.lua    # tmux ↔ nvim pane navigation
        └── chezmoi.lua         # edit/apply dotfiles source in place
```

## Overrides, and why

| Override                      | LazyVim default   | Reason                                      |
| ----------------------------- | ----------------- | ------------------------------------------- |
| `scrolloff = 8`               | `4`               | taste                                       |
| `inccommand = "split"`        | `"nosplit"`       | preview `:s` results in a split             |
| `breakindent`                 | unset             | LazyVim force-wraps text/markdown/gitcommit |
| custom `listchars`            | nvim default      | `» · ␣` over `> - +`                        |
| `jk` → `<Esc>`                | unmapped          | muscle memory                               |
| `<C-d>`/`<C-u>` + `zz`        | unmapped          | keep the cursor centred                     |
| `formatoptions:remove{o,r}`   | global `jcroqlnt` | stop comment leaders auto-continuing        |
| trim-on-save autocmd          | none              | autoformat only covers real formatters      |
| catppuccin mocha, transparent | tokyonight        | pairs with Ghostty's background opacity     |
| `checker.enabled = false`     | `true`            | no background fetches; update deliberately  |

Trim-on-save is an autocmd, **not** a conform `formatters_by_ft["_"]` entry: conform only falls through to the LSP when a buffer resolves no formatter at all (`conform/init.lua:640-648`), so a catch-all entry would silently disable LazyVim's LSP format-on-save for every filetype with no explicit conform formatter.

Three divergences the old config carried are deliberately abandoned rather than ported: which-key `delay = 300` (which-key's own default is 200), snacks `explorer.replace_netrw = false` (snacks defaults it to `true`, so the explorer now takes netrw's place), and the `<leader>fh` help binding — see the trap below.

## Cross-tool integration

- **tmux**: `smart-splits.nvim` sets the tmux user option `@pane-is-vim`; `keybinds.conf` branches on it so `M-H/J/K/L` navigates nvim splits inside a vim pane and tmux panes everywhere else. Same arbitration routes the `Ctrl+Shift W/E/A/S` rewrites. Dropping this plugin breaks both, silently and differently: `M-H/J/K/L` falls back to `select-pane` (tmux panes only, never nvim splits), while `Ctrl+Shift W/E/A/S` sends the vim pane `M-C-w/e/a/s` — the zsh sequence, which nvim does not bind (`keybinds.conf:46-53` and `:63-66`).
- **chezmoi**: `chezmoi.nvim` watches `~/.dotfiles/*` so source edits apply on write.

## Keymaps

LazyVim's own — `<leader>` is `Space`, `<leader>?` lists buffer-local maps, and `keys` (the tmux `M-?` cheatsheet) reads them live from nvim. Three traps worth remembering: `<leader>fg` is **git files**, grep is `<leader>sg` or `<leader>/`; help pages moved from `<leader>fh` (unmapped now) to `<leader>sh`; and `<leader>e` comes from the `editor.snacks_explorer` extra, not from core.

## Updating

`checker` is off by design. Update deliberately:

```sh
nvim --headless "+Lazy! update" +qa   # or :Lazy update in a session
home re-add                            # capture the new lazy-lock.json
```

Never `:Lazy sync` — it uninstalls anything missing from the current spec.
