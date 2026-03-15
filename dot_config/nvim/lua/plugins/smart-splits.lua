return {
  "mrjones2014/smart-splits.nvim",
  lazy = false,
  config = function()
    local ss = require("smart-splits")
    ss.setup()
    vim.keymap.set("n", "<C-M-h>", ss.move_cursor_left, { desc = "Move to left pane" })
    vim.keymap.set("n", "<C-M-j>", ss.move_cursor_down, { desc = "Move to lower pane" })
    vim.keymap.set("n", "<C-M-k>", ss.move_cursor_up, { desc = "Move to upper pane" })
    vim.keymap.set("n", "<C-M-l>", ss.move_cursor_right, { desc = "Move to right pane" })
  end,
}
