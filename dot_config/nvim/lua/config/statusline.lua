local M = {}

function M.setup()
  local statusline = require 'mini.statusline'
  local branches = {}

  vim.o.laststatus = 3 -- One full-width bar, including when Neo-tree has focus.

  local function context_directory()
    if vim.bo.filetype == 'neo-tree' then
      local manager = package.loaded['neo-tree.sources.manager']
      local state = manager and manager.get_state_for_window()
      if state and state.path then return state.path end
    end
    if vim.bo.buftype == '' then
      local name = vim.api.nvim_buf_get_name(0)
      if name ~= '' then return vim.fs.dirname(name) end
    end
    return vim.fn.getcwd()
  end

  -- Never run blocking Git commands from the statusline. Cache by directory
  -- so switching repositories cannot display another repository's branch.
  local function refresh_branch(force)
    if vim.fn.executable 'git' ~= 1 then return end
    local directory = context_directory()
    local entry = branches[directory]
    local now = vim.uv.now()
    if entry and (entry.pending or (not force and now - entry.checked < 2000)) then return end
    entry = entry or { text = '' }
    branches[directory] = entry
    entry.pending, entry.checked = true, now

    local function finish(text)
      vim.schedule(function()
        entry.text, entry.pending, entry.checked = text, false, vim.uv.now()
        vim.cmd.redrawstatus()
      end)
    end

    vim.system({ 'git', '-C', directory, 'symbolic-ref', '--quiet', '--short', 'HEAD' }, { text = true }, function(result)
      if result.code == 0 then
        finish(' ' .. vim.trim(result.stdout))
        return
      end
      -- Detached HEAD: show the commit instead. Outside Git: show nothing.
      vim.system({ 'git', '-C', directory, 'rev-parse', '--short', 'HEAD' }, { text = true }, function(head)
        finish(head.code == 0 and (' ' .. vim.trim(head.stdout) .. ' (detached)') or '')
      end)
    end)
  end

  local function escape(text) return (text:gsub('%%', '%%%%')) end

  statusline.setup {
    use_icons = false,
    content = {
      active = function()
        local entry = branches[context_directory()]
        -- Neo-tree can change roots without switching buffers.
        if not entry then vim.schedule(function() refresh_branch(false) end) end
        local branch = entry and escape(entry.text) or ''
        local mode, mode_hl = statusline.section_mode { trunc_width = 0 }
        local is_file = vim.bo.buftype == ''
        local filename = '%f%m%r'
        if vim.bo.filetype == 'neo-tree' then
          filename = 'Neo-tree'
        elseif not is_file then
          filename = escape(vim.bo.filetype ~= '' and vim.bo.filetype or 'Preview')
        elseif vim.api.nvim_buf_get_name(0) == '' then
          filename = '[No name]%m'
        end

        local diagnostics = ''
        if is_file then
          diagnostics = statusline.section_diagnostics {
            trunc_width = 0,
            icon = '',
            signs = { ERROR = 'E:', WARN = 'W:', INFO = 'I:', HINT = 'H:' },
          }
        end
        local filetype = is_file and escape(vim.bo.filetype) or ''
        local location = is_file and '%l:%v' or ''
        local search = is_file and statusline.section_searchcount { trunc_width = 75 } or ''

        return statusline.combine_groups {
          { hl = mode_hl, strings = { mode } },
          { hl = 'MiniStatuslineDevinfo', strings = { branch } },
          '%<', -- Prefer truncating the filename, not the branch.
          { hl = 'MiniStatuslineFilename', strings = { filename } },
          '%=',
          { hl = 'MiniStatuslineDevinfo', strings = { diagnostics } },
          { hl = 'MiniStatuslineFileinfo', strings = { filetype } },
          { hl = mode_hl, strings = { search, location } },
        }
      end,
    },
  }

  local group = vim.api.nvim_create_augroup('ConfigStatuslineBranch', { clear = true })
  vim.api.nvim_create_autocmd({ 'BufEnter', 'WinEnter', 'FileType', 'DirChanged', 'FocusGained', 'TermClose', 'BufWritePost', 'CursorHold' }, {
    group = group,
    callback = function()
      vim.schedule(function() refresh_branch(false) end)
    end,
  })
  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'GitSignsUpdate',
    callback = function()
      vim.schedule(function() refresh_branch(true) end)
    end,
  })
  refresh_branch(true)
end

return M
