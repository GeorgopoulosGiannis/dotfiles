vim.pack.add { 'https://github.com/mfussenegger/nvim-lint' }

local lint = require 'lint'
lint.linters_by_ft = {
  markdown = { 'markdownlint' }, -- installed by mason-tool-installer (init.lua)
}

vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
  group = vim.api.nvim_create_augroup('lint', { clear = true }),
  callback = function()
    -- Skip unmodifiable buffers (e.g. LSP hover popups rendered as Markdown).
    if vim.bo.modifiable then lint.try_lint() end
  end,
})
