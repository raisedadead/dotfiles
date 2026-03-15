# nvim

Minimal, modular Neovim config. Transparent, keyboard-first, no statusline.

Requires: Neovim 0.11+, `tree-sitter-cli`, a Nerd Font.

## Structure

```
nvim/
├── init.lua                    # lazy.nvim bootstrap
└── lua/
    ├── config/
    │   ├── options.lua         # core vim settings
    │   ├── keymaps.lua         # keybindings
    │   └── autocmds.lua        # autocommands
    └── plugins/
        ├── catppuccin.lua      # theme (mocha, transparent)
        ├── snacks.lua          # explorer, picker, statuscolumn
        ├── treesitter.lua      # syntax (22 parsers)
        └── editor.lua          # mini.pairs, mini.surround
```

## Plugins

| Plugin                                                                | Purpose                        |
| --------------------------------------------------------------------- | ------------------------------ |
| [lazy.nvim](https://github.com/folke/lazy.nvim)                       | Plugin manager                 |
| [catppuccin](https://github.com/catppuccin/nvim)                      | Mocha theme, transparent bg    |
| [snacks.nvim](https://github.com/folke/snacks.nvim)                   | Explorer, picker, statuscolumn |
| [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) | Parser management              |
| [mini.pairs](https://github.com/echasnovski/mini.pairs)               | Auto-close brackets            |
| [mini.surround](https://github.com/echasnovski/mini.surround)         | Surround operations            |

## Keymaps

Leader: `Space`

### Navigation

| Key           | Action               |
| ------------- | -------------------- |
| `C-h/j/k/l`   | Window navigation    |
| `C-Arrow`     | Resize windows       |
| `[b` / `]b`   | Prev/next buffer     |
| `S-h` / `S-l` | Prev/next buffer     |
| `]d` / `[d`   | Next/prev diagnostic |

### Editing

| Key                | Action                 |
| ------------------ | ---------------------- |
| `Alt-j/k`          | Move line(s) up/down   |
| `<` / `>` (visual) | Indent and reselect    |
| `sa{motion}{char}` | Add surround           |
| `sd{char}`         | Delete surround        |
| `sr{old}{new}`     | Replace surround       |
| `Esc`              | Clear search highlight |

### Snacks

| Key                              | Action        |
| -------------------------------- | ------------- |
| `<leader>e`                      | File explorer |
| `<leader>ff` / `<leader><space>` | Find files    |
| `<leader>fg` / `<leader>/`       | Live grep     |
| `<leader>fb` / `<leader>,`       | Buffers       |
| `<leader>fh`                     | Help pages    |
| `<leader>fr`                     | Recent files  |

## Autocommands

- Highlight on yank
- Restore cursor position
- Close help/man/qf with `q`
- Trim trailing whitespace on save (skips files >10k lines)
- Auto-resize splits on terminal resize
