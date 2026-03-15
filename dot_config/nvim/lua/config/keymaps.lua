local map = vim.keymap.set

-- Better up/down on wrapped lines
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, desc = "Down (wrapped)" })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = "Up (wrapped)" })

-- Resize windows
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

-- Buffer cycling (S-h/S-l aliases; [b/]b are built-in since 0.11)
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })

-- Move lines
map("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move line down", silent = true })
map("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move line up", silent = true })
map("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move selection down", silent = true })
map("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move selection up", silent = true })

-- Better indenting (stay in visual mode)
map("v", "<", "<gv", { desc = "Indent left and reselect", silent = true })
map("v", ">", ">gv", { desc = "Indent right and reselect", silent = true })

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear hlsearch" })

-- Exit insert mode with jk
map("i", "jk", "<Esc>", { desc = "Exit insert mode" })

-- Save with Ctrl+S
map({ "n", "i", "x" }, "<C-s>", "<cmd>update<cr><esc>", { desc = "Save file" })

-- Exit terminal mode
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Center screen after search/scroll
map("n", "n", "nzzzv", { desc = "Next search result (centered)" })
map("n", "N", "Nzzzv", { desc = "Prev search result (centered)" })
map("n", "<C-d>", "<C-d>zz", { desc = "Scroll down (centered)" })
map("n", "<C-u>", "<C-u>zz", { desc = "Scroll up (centered)" })
