vim.pack.add { 'https://github.com/folke/flash.nvim' }

require('flash').setup {
  modes = {
    -- Keep native search and character motions unchanged.
    search = { enabled = false },
    char = { enabled = false },
  },
}

vim.keymap.set({ 'n', 'x', 'o' }, 's', function() require('flash').jump() end, { desc = 'Flash jump' })
-- Visual S belongs to nvim-surround; use gs consistently for node selection.
vim.keymap.set({ 'n', 'x', 'o' }, 'gs', function() require('flash').treesitter() end, { desc = 'Flash Treesitter selection' })
