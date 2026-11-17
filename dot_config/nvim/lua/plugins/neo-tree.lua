vim.pack.add {
  { src = 'https://github.com/nvim-neo-tree/neo-tree.nvim', version = vim.version.range '*' },
  'https://github.com/MunifTanjim/nui.nvim',
}

-- reveal=false: follow_current_file otherwise implies a reveal, which prompts
-- "File not in cwd. Change cwd to ...?" for files outside the cwd.
vim.keymap.set('n', '\\', function() require('neo-tree.command').execute { toggle = true, reveal = false } end, { desc = 'NeoTree toggle', silent = true })

--- Copy a value derived from the node under the cursor to the clipboard.
---@param label string
---@param get fun(node: table): string
local function copy_from_node(label, get)
  return function(state)
    local value = get(state.tree:get_node())
    vim.fn.setreg('+', value)
    vim.notify(('Copied %s: %s'):format(label, value))
  end
end

require('neo-tree').setup {
  buffers = {
    follow_current_file = { enabled = true },
  },

  filesystem = {
    follow_current_file = { enabled = true },
    window = {
      mappings = {
        ['\\'] = 'close_window',
        -- The default `y` (copy_to_clipboard) has nowait=true, so it fires
        -- immediately and the yp/yr/yn combos below never get their second key.
        ['y'] = { 'copy_to_clipboard', nowait = false },
        ['yp'] = { command = copy_from_node('path', function(node) return node:get_id() end), desc = 'copy_absolute_path' },
        ['yr'] = { command = copy_from_node('relative path', function(node) return vim.fn.fnamemodify(node:get_id(), ':.') end), desc = 'copy_relative_path' },
        ['yn'] = { command = copy_from_node('name', function(node) return node.name end), desc = 'copy_filename' },
      },
    },
  },
}
