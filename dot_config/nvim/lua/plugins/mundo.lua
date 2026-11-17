-- vim-mundo is a Vimscript plugin; no Lua setup is required.
vim.pack.add { 'https://github.com/simnalamburt/vim-mundo' }

vim.g.mundo_close_on_revert = 1
vim.g.mundo_right = 1
vim.g.mundo_width = 50
vim.g.mundo_preview_height = 50

vim.keymap.set('n', '<leader>u', '<cmd>MundoToggle<CR>', { desc = 'Undo tree (Mundo)' })
