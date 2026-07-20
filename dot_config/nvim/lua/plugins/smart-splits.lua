return {
  "mrjones2014/smart-splits.nvim",
  lazy = false,
  config = function()
    local ss = require("smart-splits")
    ss.setup()
    vim.keymap.set("n", "<A-H>", ss.move_cursor_left, { desc = "Move to left pane" })
    vim.keymap.set("n", "<A-J>", ss.move_cursor_down, { desc = "Move to lower pane" })
    vim.keymap.set("n", "<A-K>", ss.move_cursor_up, { desc = "Move to upper pane" })
    vim.keymap.set("n", "<A-L>", ss.move_cursor_right, { desc = "Move to right pane" })
  end,
}
