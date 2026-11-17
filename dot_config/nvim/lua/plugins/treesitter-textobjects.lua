vim.pack.add { { src = 'https://github.com/nvim-treesitter/nvim-treesitter-textobjects', version = 'main' } }

require('nvim-treesitter-textobjects').setup {
  select = {
    lookahead = true,
    selection_modes = {
      ['@function.outer'] = 'V',
      ['@class.outer'] = 'V',
    },
  },
  move = { set_jumps = true },
}

-- Keep mini.ai's function-call (af/if) objects intact.
-- Use "m" for a method/function definition and "c" for a class.
for keys, object in pairs {
  am = { '@function.outer', 'Around method/function' },
  im = { '@function.inner', 'Inside method/function' },
  ac = { '@class.outer', 'Around class' },
  ic = { '@class.inner', 'Inside class' },
} do
  vim.keymap.set(
    { 'x', 'o' },
    keys,
    function() require('nvim-treesitter-textobjects.select').select_textobject(object[1], 'textobjects') end,
    { desc = object[2] }
  )
end

-- Scope boundaries come from each language's locals queries. There is no
-- separate inner-scope capture, so only an "around" object exists. It lives on
-- aS because `as` is Vim's built-in sentence object.
vim.keymap.set(
  { 'x', 'o' },
  'aS',
  function() require('nvim-treesitter-textobjects.select').select_textobject('@local.scope', 'locals') end,
  { desc = 'Around local scope' }
)

-- Swap the argument/parameter under the cursor; this is a local edit, not a
-- project-wide signature refactor. Use inner captures in both directions.
vim.keymap.set(
  'n',
  '<leader>a',
  function() require('nvim-treesitter-textobjects.swap').swap_next '@parameter.inner' end,
  { desc = 'Swap argument/parameter with next' }
)
vim.keymap.set(
  'n',
  '<leader>A',
  function() require('nvim-treesitter-textobjects.swap').swap_previous '@parameter.inner' end,
  { desc = 'Swap argument/parameter with previous' }
)

-- Buffer-local maps take precedence over language ftplugin maps (e.g. Python),
-- without disabling unrelated built-in filetype mappings globally.
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('treesitter-textobjects', { clear = true }),
  callback = function(event)
    for keys, motion in pairs {
      [']m'] = { 'goto_next_start', 'Next function start' },
      ['[m'] = { 'goto_previous_start', 'Previous function start' },
      [']M'] = { 'goto_next_end', 'Next function end' },
      ['[M'] = { 'goto_previous_end', 'Previous function end' },
    } do
      vim.keymap.set(
        { 'n', 'x', 'o' },
        keys,
        function() require('nvim-treesitter-textobjects.move')[motion[1]]('@function.outer', 'textobjects') end,
        { buffer = event.buf, desc = motion[2] }
      )
    end
  end,
})
