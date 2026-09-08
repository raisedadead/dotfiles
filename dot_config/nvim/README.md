# Neovim

LazyVim with local overrides. `lua/config/` holds options, keymaps, and autocmds; `lua/plugins/` holds plugin configuration. `lazyvim.json` selects extras, and `lazy-lock.json` records plugin revisions.

Maintenance and integration contracts live in `~/.dotfiles/docs/ARCHI.md`, in the Neovim section. Edit deployed dotfiles, validate, then capture them with chezmoi. Source-buffer saves do not apply automatically.

Update with `:Lazy update`, then `chezmoi re-add ~/.config/nvim/lazy-lock.json`. Use `:checkhealth` for diagnostics. Read the plugin spec before using `:Lazy sync`, which can remove plugins.
