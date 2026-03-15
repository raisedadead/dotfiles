return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    explorer = { enabled = true, replace_netrw = false },
    picker = { enabled = true },
    statuscolumn = { enabled = true },
  },
  keys = {
    { "<leader>e", function() Snacks.explorer() end, desc = "File Explorer" },
    { "<leader>ff", function() Snacks.picker.files() end, desc = "Find Files" },
    { "<leader>fg", function() Snacks.picker.grep() end, desc = "Grep" },
    { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
    { "<leader>fh", function() Snacks.picker.help() end, desc = "Help Pages" },
    { "<leader>fr", function() Snacks.picker.recent() end, desc = "Recent Files" },
    { "<leader>/", function() Snacks.picker.grep() end, desc = "Grep (root)" },
    { "<leader>,", function() Snacks.picker.buffers() end, desc = "Buffers" },
    { "<leader><space>", function() Snacks.picker.files() end, desc = "Find Files" },
  },
}
