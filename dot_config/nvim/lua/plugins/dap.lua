-- Debugging (nvim-dap + UI) and .NET tooling (easy-dotnet).
-- mason.nvim and plenary.nvim are installed earlier in init.lua.

vim.pack.add {
  'https://github.com/mfussenegger/nvim-dap',
  'https://github.com/rcarriga/nvim-dap-ui',
  'https://github.com/nvim-neotest/nvim-nio',
  'https://github.com/jay-babu/mason-nvim-dap.nvim',
  'https://github.com/leoluz/nvim-dap-go',
  'https://github.com/folke/snacks.nvim',
  'https://github.com/GustavEikaas/easy-dotnet.nvim',
}

local dap = require 'dap'
local dapui = require 'dapui'

-- VS Code compatible keybindings
vim.keymap.set('n', '<F5>', dap.continue, { desc = 'Debug: Start / Continue' })
vim.keymap.set('n', '<S-F5>', dap.terminate, { desc = 'Debug: Terminate' })
vim.keymap.set('n', '<F9>', dap.toggle_breakpoint, { desc = 'Debug: Toggle Breakpoint' })
vim.keymap.set('n', '<F10>', dap.step_over, { desc = 'Debug: Step Over' })
vim.keymap.set('n', '<F11>', dap.step_into, { desc = 'Debug: Step Into' })
vim.keymap.set('n', '<S-F11>', dap.step_out, { desc = 'Debug: Step Out' })
vim.keymap.set('n', '<F7>', dapui.toggle, { desc = 'Debug: Toggle UI' })
vim.keymap.set('n', '<leader>b', dap.toggle_breakpoint, { desc = 'Debug: Toggle Breakpoint' })
vim.keymap.set('n', '<leader>B', function() dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ') end, { desc = 'Debug: Set Conditional Breakpoint' })

-- Only break on exceptions nobody handles.
dap.defaults.fallback.exception_breakpoints = { 'userUnhandled' }

require('mason-nvim-dap').setup {
  automatic_installation = true,
  handlers = {
    -- nvim-dap-go registers the Go adapter and configs below, so skip delve here.
    delve = function() end,
  },
  ensure_installed = { 'netcoredbg', 'delve' },
}

require('dap-go').setup {
  delve = {
    -- On Windows delve must be run attached or it crashes.
    detached = vim.fn.has 'win32' == 0,
  },
}
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('go-dap-keymaps', { clear = true }),
  pattern = 'go',
  callback = function(ev)
    vim.keymap.set('n', '<leader>dt', function() require('dap-go').debug_test() end, { buffer = ev.buf, desc = 'Debug: Go [T]est under cursor' })
  end,
})

-- easy-dotnet wires up the project runner, solution builder, and DAP configs
require('easy-dotnet').setup {
  diagnostics = {
    setqflist = true,
  },
  terminal = {
    auto_close = false,
  },
  test_runner = {
    env = {
      DiffEngine_ToolOrder = 'Neovim|VisualStudioCode|Rider',
    },
    -- Runner-buffer keys. Python/Go/Git keys are buffer-local elsewhere, so these
    -- don't collide. Debug is <leader>D because <leader>d is the global .NET group.
    mappings = {
      debug_test = { lhs = '<leader>D', desc = 'debug test' },
      peek_stacktrace = { lhs = '<leader>p', desc = 'peek results of failed test' },
    },
  },
  -- Roslyn LSP managed by easy-dotnet
  lsp = {
    enabled = true,
    config = {
      settings = {
        ['csharp|inlay_hints'] = {
          csharp_enable_inlay_hints_for_implicit_variable_types = true,
          csharp_enable_inlay_hints_for_types = true,
          csharp_enable_inlay_hints_for_implicit_object_creation = true,
          csharp_enable_inlay_hints_for_lambda_parameter_types = true,
        },
      },
    },
  },
}
vim.keymap.set('n', '<leader>dr', '<cmd>Dotnet run<CR>', { desc = '.NET Run' })
vim.keymap.set('n', '<leader>dd', '<cmd>Dotnet debug default profile<CR>', { desc = '.NET Debug' })

---@diagnostic disable-next-line: missing-fields
dapui.setup {
  -- dapui's default layouts (scopes/breakpoints/stacks/watches on the left,
  -- repl/console at the bottom) plus a right sidebar for easy-dotnet's CPU and memory.
  layouts = {
    {
      elements = {
        { id = 'scopes', size = 0.25 },
        { id = 'breakpoints', size = 0.25 },
        { id = 'stacks', size = 0.25 },
        { id = 'watches', size = 0.25 },
      },
      size = 40,
      position = 'left',
    },
    {
      elements = { 'repl', 'console' },
      size = 10,
      position = 'bottom',
    },
    {
      elements = {
        { id = 'easy-dotnet_cpu', size = 0.5 },
        { id = 'easy-dotnet_mem', size = 0.5 },
      },
      size = 35,
      position = 'right',
    },
  },
  icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
  ---@diagnostic disable-next-line: missing-fields
  controls = {
    icons = {
      pause = '⏸',
      play = '▶',
      step_into = '⏎',
      step_over = '⏭',
      step_out = '⏮',
      step_back = 'b',
      run_last = '▶▶',
      terminate = '⏹',
      disconnect = '⏏',
    },
  },
}

-- Breakpoint gutter icons
vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#e51400' })
vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })
local breakpoint_icons = vim.g.have_nerd_font
    and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
  or { Breakpoint = '●', BreakpointCondition = '⊜', BreakpointRejected = '⊘', LogPoint = '◆', Stopped = '⭔' }
for type, icon in pairs(breakpoint_icons) do
  local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
  vim.fn.sign_define('Dap' .. type, { text = icon, texthl = hl, numhl = hl })
end

dap.listeners.after.event_initialized['dapui_config'] = dapui.open
dap.listeners.before.event_terminated['dapui_config'] = dapui.close
dap.listeners.before.event_exited['dapui_config'] = dapui.close
