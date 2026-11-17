vim.pack.add { 'https://github.com/lukas-reineke/indent-blankline.nvim' }
require('ibl').setup {}

-- mini.indentscope (from mini.nvim, loaded in init.lua) is used only for its
-- [i / ]i motions to the top / bottom of the current scope.
require('mini.indentscope').setup {
  -- indent-blankline stays the only provider of visual indentation guides.
  draw = {
    predicate = function() return false end,
  },
  -- Motions only; leave mini.ai's `ii` prefix and text objects alone.
  mappings = {
    object_scope = '',
    object_scope_with_border = '',
  },
}
