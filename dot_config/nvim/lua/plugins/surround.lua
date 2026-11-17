vim.pack.add { { src = 'https://github.com/kylechui/nvim-surround', version = vim.version.range '4.x' } }

-- ysiw" quotes a word; yss" quotes a line; ds" deletes quotes; cs"' changes them.
-- Visual S surrounds selected text, which is why flash.nvim leaves it alone.
require('nvim-surround').setup {}
