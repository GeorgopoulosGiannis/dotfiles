vim.pack.add { 'https://github.com/linux-cultist/venv-selector.nvim' }

require('venv-selector').setup {}

vim.keymap.set('n', '<leader>pv', '<cmd>VenvSelect<CR>', { desc = '[P]ython [V]env select' })
