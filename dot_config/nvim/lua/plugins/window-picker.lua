vim.pack.add { 'https://github.com/s1n7ax/nvim-window-picker' }

require('window-picker').setup {
  hint = 'floating-big-letter',
}

vim.keymap.set('n', '<leader>w', function()
  local picked_window_id = require('window-picker').pick_window()
  if picked_window_id then vim.api.nvim_set_current_win(picked_window_id) end
end, { desc = 'Pick a window to jump to' })
