vim.pack.add { 'https://github.com/linux-cultist/venv-selector.nvim' }

require('venv-selector').setup {}

-- Python keys only exist in Python buffers, so <leader>p is free elsewhere
-- (e.g. the easy-dotnet test runner uses it to peek results).
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('python-keymaps', { clear = true }),
  pattern = 'python',
  callback = function(ev)
    require('which-key').add { { '<leader>p', group = '[P]ython', buffer = ev.buf } }
    vim.keymap.set('n', '<leader>pv', '<cmd>VenvSelect<CR>', { buffer = ev.buf, desc = '[P]ython [V]env select' })
  end,
})
