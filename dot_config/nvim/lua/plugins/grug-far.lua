vim.pack.add { 'https://github.com/MagicDuck/grug-far.nvim' }

require('grug-far').setup {}

vim.keymap.set({ 'n', 'v' }, '<leader>sR', function() require('grug-far').open { transient = true } end, { desc = '[S]earch and [R]eplace (grug-far)' })
