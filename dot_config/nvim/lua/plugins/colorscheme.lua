return {
  -- LazyVim owns the `colorscheme` call; setting it here instead of
  -- `vim.cmd.colorscheme` keeps its startup ordering and fallback intact.
  --
  -- The flavour-specific name is load-bearing: Neovim 0.12 ships its own
  -- `$VIMRUNTIME/colors/catppuccin.vim`, and a bare `catppuccin` resolves to
  -- that builtin — which ignores the plugin's options, so
  -- `transparent_background` silently does nothing. `catppuccin-mocha` exists
  -- only in the plugin, so there is nothing to collide with.
  { "LazyVim/LazyVim", opts = { colorscheme = "catppuccin-mocha" } },

  {
    "catppuccin/nvim",
    name = "catppuccin",
    -- integrations/lsp_styles come from LazyVim's own spec and merge in.
    opts = {
      flavour = "mocha",
      transparent_background = true, -- pairs with Ghostty's background opacity
    },
  },
}
