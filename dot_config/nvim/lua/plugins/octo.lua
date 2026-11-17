vim.pack.add { 'https://github.com/pwntester/octo.nvim' }

require('octo').setup {
  enable_builtin = true,
  picker = 'telescope',
  use_local_fs = true,
  timeout = 20000,
}

vim.keymap.set('n', '<leader>O', '<cmd>Octo<cr>', { desc = 'Octo' })
