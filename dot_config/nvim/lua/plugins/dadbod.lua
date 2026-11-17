vim.pack.add {
  'https://github.com/tpope/vim-dadbod',
  'https://github.com/kristijanhusak/vim-dadbod-ui',
  'https://github.com/kristijanhusak/vim-dadbod-completion',
}

vim.g.db_ui_use_nerd_fonts = 1
vim.g.db_ui_save_location = vim.fn.stdpath 'data' .. '/dadbod_ui'

vim.keymap.set('n', '<leader>D', '<cmd>DBUI<cr>', { desc = 'Dadbod UI' })

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'sql', 'mysql', 'plsql' },
  callback = function() vim.bo.omnifunc = 'vim_dadbod_completion#omni' end,
})
