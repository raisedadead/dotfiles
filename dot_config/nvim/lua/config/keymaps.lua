local map = vim.keymap.set

-- Exit insert mode without reaching for Esc
map("i", "jk", "<Esc>", { desc = "Exit insert mode" })

-- Keep the cursor centred while half-page scrolling.
map("n", "<C-d>", "<C-d>zz", { desc = "Scroll down (centered)" })
map("n", "<C-u>", "<C-u>zz", { desc = "Scroll up (centered)" })

-- Ghostty sends Ctrl+Shift+W/E/A/S as ESC + Ctrl byte; give Neovim the plain key
for _, key in ipairs({ "w", "e", "a", "s" }) do
  map(
    { "n", "i", "c", "x", "s", "o" },
    "<M-C-" .. key .. ">",
    "<C-" .. key .. ">",
    { remap = true, desc = "Ctrl+" .. key:upper() }
  )
end

local splits = require("smart-splits")
map("n", "<A-H>", splits.move_cursor_left, { desc = "Move to left pane" })
map("n", "<A-J>", splits.move_cursor_down, { desc = "Move to lower pane" })
map("n", "<A-K>", splits.move_cursor_up, { desc = "Move to upper pane" })
map("n", "<A-L>", splits.move_cursor_right, { desc = "Move to right pane" })

local function project_dir()
  return vim.fs.root(0, ".git") or vim.fs.root(vim.fn.getcwd(), ".git") or vim.fn.getcwd()
end

map("n", "<leader><space>", function()
  Snacks.picker.files({ cwd = project_dir() })
end, { desc = "Find project files" })

map("n", "<leader>/", function()
  Snacks.picker.grep({ cwd = project_dir() })
end, { desc = "Grep project" })

map("n", "<leader>e", function()
  Snacks.explorer.open({ cwd = project_dir() })
end, { desc = "Toggle project tree" })

map("n", "<leader>cf", function()
  local chezmoi = require("chezmoi.commands")
  local files = chezmoi.list({ args = { "--path-style", "absolute", "--include", "files", "--exclude", "externals" } })
  local items = vim.tbl_map(function(file)
    return { text = file, file = file }
  end, files)
  Snacks.picker.pick({
    title = "Chezmoi files",
    items = items,
    format = "file",
    -- The upstream Snacks adapter passes --watch, overriding edit.watch.
    confirm = function(picker, item)
      if item then
        picker:close()
        chezmoi.edit({ targets = { item.file } })
      end
    end,
  })
end, { desc = "Find chezmoi files" })
