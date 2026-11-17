-- In-buffer rendering (headings, code blocks, tables, callouts, checkboxes).
vim.pack.add { 'https://github.com/MeanderingProgrammer/render-markdown.nvim' }

require('render-markdown').setup {
  -- Checkbox / callout completions via in-process LSP (works with blink.cmp)
  completions = { lsp = { enabled = true } },
}

vim.keymap.set('n', '<leader>mp', '<cmd>RenderMarkdown buf_toggle<CR>', { desc = 'Markdown: toggle render' })
vim.keymap.set('n', '<leader>ms', '<cmd>RenderMarkdown preview<CR>', { desc = 'Markdown: rendered side preview' })

-- Browser preview. vim.pack has no build hook, so build the app on install/update.
vim.api.nvim_create_autocmd('PackChanged', {
  callback = function(ev)
    local d = ev.data
    if d.spec.name == 'markdown-preview.nvim' and (d.kind == 'install' or d.kind == 'update') then
      vim.system({ 'npx', '--yes', 'yarn', 'install' }, { cwd = d.path .. '/app' })
    end
  end,
})

vim.pack.add { 'https://github.com/iamcco/markdown-preview.nvim' }

vim.g.mkdp_filetypes = { 'markdown' }

vim.keymap.set('n', '<leader>mw', '<cmd>MarkdownPreviewToggle<CR>', { desc = 'Markdown preview (web)' })
