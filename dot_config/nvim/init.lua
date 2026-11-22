-- Personal Neovim config (Neovim >= 0.12, plugins via the built-in vim.pack).
-- Derived from kickstart.nvim (https://github.com/nvim-lua/kickstart.nvim), MIT licensed: see LICENSE.md.
-- Per-plugin setup lives in lua/plugins/*.lua; `:checkhealth config` checks the basics.

-- ============================================================
-- Options
-- ============================================================
do
  vim.loader.enable()

  -- Leaders must be set before plugins load
  vim.g.mapleader = ' '
  vim.g.maplocalleader = ' '

  vim.g.have_nerd_font = true

  -- Treat .fs files as F# (not Forth)
  vim.g.filetype_fs = 'fsharp'

  vim.o.number = true
  vim.o.relativenumber = true
  vim.o.mouse = 'a'
  vim.o.showmode = false -- the statusline already shows it
  vim.o.cmdheight = 0 -- Hide the command line when idle

  -- Scheduled: setting the clipboard provider eagerly slows startup
  vim.schedule(function() vim.o.clipboard = 'unnamedplus' end)

  vim.o.breakindent = true

  vim.o.undofile = true
  vim.o.undolevels = 1000
  local undo_dir = vim.fn.stdpath 'state' .. '/undo'
  vim.fn.mkdir(undo_dir, 'p')
  vim.opt.undodir = undo_dir
  vim.o.swapfile = false

  vim.o.ignorecase = true
  vim.o.smartcase = true

  vim.o.signcolumn = 'yes'
  vim.o.updatetime = 250
  vim.o.timeoutlen = 300

  vim.o.splitright = true
  vim.o.splitbelow = true

  vim.o.list = true
  vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

  -- When appending to a register, add a new line in between
  vim.opt.cpoptions:append '>'
  vim.o.inccommand = 'split' -- live substitution preview

  vim.o.cursorline = true
  vim.o.scrolloff = 10

  -- Keep folds open by default while still allowing manual folding commands.
  vim.o.foldlevel = 99
  vim.o.foldlevelstart = 99

  -- Ask to save instead of failing on `:q` with unsaved changes
  vim.o.confirm = true
end

-- ============================================================
-- Keymaps & autocmds
-- ============================================================
do
  vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

  vim.diagnostic.config {
    update_in_insert = false,
    severity_sort = true,
    float = { border = 'rounded', source = 'if_many' },
    underline = { severity = { min = vim.diagnostic.severity.WARN } },
    virtual_text = true,
    virtual_lines = false,

    -- Open the float automatically when jumping with `[d` / `]d`
    jump = {
      on_jump = function(_, bufnr)
        vim.diagnostic.open_float {
          bufnr = bufnr,
          scope = 'cursor',
          focus = false,
        }
      end,
    },
  }

  vim.keymap.set('n', '<leader>yd', function()
    local line = vim.fn.line '.' - 1
    local diags = vim.diagnostic.get(0, { lnum = line })

    if #diags == 0 then
      vim.notify('No diagnostic on current line', vim.log.levels.WARN)
      return
    end

    local lines = {}
    for i, d in ipairs(diags) do
      local source = d.source and ('[' .. d.source .. '] ') or ''
      local code = d.code and (' (' .. d.code .. ')') or ''
      table.insert(lines, string.format('%d. %s%s%s', i, source, d.message, code))
    end

    vim.fn.setreg('+', table.concat(lines, '\n\n'))
    vim.notify 'Copied full diagnostic details to clipboard!'
  end, { desc = 'Yank full diagnostic to clipboard' })

  vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

  -- Won't work in every terminal/tmux setup; <C-\><C-n> always does.
  vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

  vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
  vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
  vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
  vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

  vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
    callback = function() vim.hl.on_yank() end,
  })

  vim.filetype.add {
    extension = {
      j2 = 'jinja',
      jinja = 'jinja',
      jinja2 = 'jinja',
    },
  }

  -- Diff the buffer against the file on disk
  vim.api.nvim_create_user_command('DiffOrig', function() vim.cmd 'vert new | set bt=nofile | r ++edit # | 0d_ | diffthis | wincmd p | diffthis' end, {})
end

-- ============================================================
-- Plugin manager (vim.pack): build hooks
-- ============================================================
do
  local function run_build(name, cmd, cwd)
    local result = vim.system(cmd, { cwd = cwd }):wait()
    if result.code ~= 0 then
      local stderr = result.stderr or ''
      local stdout = result.stdout or ''
      local output = stderr ~= '' and stderr or stdout
      if output == '' then output = 'No output from build command.' end
      vim.notify(('Build failed for %s:\n%s'):format(name, output), vim.log.levels.ERROR)
    end
  end

  -- Run build steps after a plugin is installed or updated (see `:help vim.pack-events`)
  vim.api.nvim_create_autocmd('PackChanged', {
    callback = function(ev)
      local name = ev.data.spec.name
      local kind = ev.data.kind
      if kind ~= 'install' and kind ~= 'update' then return end

      if name == 'telescope-fzf-native.nvim' and vim.fn.executable 'make' == 1 then
        run_build(name, { 'make' }, ev.data.path)
        return
      end

      if name == 'LuaSnip' then
        if vim.fn.has 'win32' ~= 1 and vim.fn.executable 'make' == 1 then run_build(name, { 'make', 'install_jsregexp' }, ev.data.path) end
        return
      end

      if name == 'nvim-treesitter' then
        if not ev.data.active then vim.cmd.packadd 'nvim-treesitter' end
        vim.cmd 'TSUpdate'
        return
      end
    end,
  })
end

---@param repo string
---@return string
local function gh(repo) return 'https://github.com/' .. repo end

-- ============================================================
-- UI / core UX: guess-indent, gitsigns, which-key, colorscheme, todo-comments, mini
-- ============================================================
do
  vim.pack.add { gh 'NMAC427/guess-indent.nvim' }
  require('guess-indent').setup {}

  vim.pack.add { gh 'lewis6991/gitsigns.nvim' }
  local gitsigns = require 'gitsigns'
  gitsigns.setup {
    signs = {
      add = { text = '+' }, ---@diagnostic disable-line: missing-fields
      change = { text = '~' }, ---@diagnostic disable-line: missing-fields
      delete = { text = '_' }, ---@diagnostic disable-line: missing-fields
      topdelete = { text = '‾' }, ---@diagnostic disable-line: missing-fields
      changedelete = { text = '~' }, ---@diagnostic disable-line: missing-fields
    },
    on_attach = function(bufnr)
      -- Buffer-local so the Git group only shows in which-key where gitsigns is attached.
      require('which-key').add { { '<leader>g', group = '[G]it', mode = { 'n', 'v' }, buffer = bufnr } }

      vim.keymap.set('n', ']c', function()
        if vim.wo.diff then
          vim.cmd.normal { ']c', bang = true }
        else
          gitsigns.nav_hunk 'next'
        end
      end, { buffer = bufnr, desc = 'Jump to next git [c]hange' })

      vim.keymap.set('n', '[c', function()
        if vim.wo.diff then
          vim.cmd.normal { '[c', bang = true }
        else
          gitsigns.nav_hunk 'prev'
        end
      end, { buffer = bufnr, desc = 'Jump to previous git [c]hange' })

      -- Visual mode actions
      vim.keymap.set('v', '<leader>gs', function() gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' } end, { buffer = bufnr, desc = 'git [s]tage hunk' })
      vim.keymap.set('v', '<leader>gr', function() gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' } end, { buffer = bufnr, desc = 'git [r]eset hunk' })
      -- Normal mode actions
      vim.keymap.set('n', '<leader>gs', gitsigns.stage_hunk, { buffer = bufnr, desc = 'git [s]tage hunk' })
      vim.keymap.set('n', '<leader>gr', gitsigns.reset_hunk, { buffer = bufnr, desc = 'git [r]eset hunk' })
      vim.keymap.set('n', '<leader>gS', gitsigns.stage_buffer, { buffer = bufnr, desc = 'git [S]tage buffer' })
      vim.keymap.set('n', '<leader>gR', gitsigns.reset_buffer, { buffer = bufnr, desc = 'git [R]eset buffer' })
      vim.keymap.set('n', '<leader>gp', gitsigns.preview_hunk, { buffer = bufnr, desc = 'git [p]review hunk' })
      vim.keymap.set('n', '<leader>gi', gitsigns.preview_hunk_inline, { buffer = bufnr, desc = 'git preview hunk [i]nline' })
      vim.keymap.set('n', '<leader>gb', function() gitsigns.blame_line { full = true } end, { buffer = bufnr, desc = 'git [b]lame line' })
      vim.keymap.set('n', '<leader>gd', gitsigns.diffthis, { buffer = bufnr, desc = 'git [d]iff against index' })
      vim.keymap.set('n', '<leader>gD', function() gitsigns.diffthis '@' end, { buffer = bufnr, desc = 'git [D]iff against last commit' })
      vim.keymap.set('n', '<leader>gQ', function() gitsigns.setqflist 'all' end, { buffer = bufnr, desc = 'git hunk [Q]uickfix list (all files in repo)' })
      vim.keymap.set('n', '<leader>gq', gitsigns.setqflist, { buffer = bufnr, desc = 'git hunk [q]uickfix list (all changes in this file)' })
      -- Toggles
      vim.keymap.set('n', '<leader>tb', gitsigns.toggle_current_line_blame, { buffer = bufnr, desc = '[T]oggle git show [b]lame line' })
      vim.keymap.set('n', '<leader>tw', gitsigns.toggle_word_diff, { buffer = bufnr, desc = '[T]oggle git intra-line [w]ord diff' })
      -- Text object
      vim.keymap.set({ 'o', 'x' }, 'ih', gitsigns.select_hunk, { buffer = bufnr, desc = 'Select git hunk' })
    end,
  }

  vim.pack.add { gh 'folke/which-key.nvim' }
  require('which-key').setup {
    delay = 0,
    icons = { mappings = vim.g.have_nerd_font },
    -- Group names for key chains defined across init.lua and lua/plugins/.
    -- Context-specific groups (Git, Python) are added buffer-locally where they apply.
    spec = {
      { '<leader>s', group = '[S]earch', mode = { 'n', 'v' } },
      { '<leader>t', group = '[T]oggle' },
      { '<leader>h', group = '[H]arpoon' },
      { '<leader>d', group = '[D]ebug / .NET' },
      { '<leader>m', group = '[M]arkdown' },
      { 'gr', group = 'LSP Actions', mode = { 'n' } },
    },
  }

  vim.pack.add { gh 'folke/tokyonight.nvim' }
  vim.cmd.colorscheme 'tokyonight-storm'

  -- Highlight todo, notes, etc in comments
  vim.pack.add { gh 'folke/todo-comments.nvim' }
  require('todo-comments').setup { signs = false }

  vim.pack.add { gh 'nvim-mini/mini.nvim' }

  if vim.g.have_nerd_font then
    require('mini.icons').setup()
    -- Plugins such as telescope.nvim still require `nvim-web-devicons`
    MiniIcons.mock_nvim_web_devicons()
  end

  -- Better around/inside textobjects, e.g. va) / yiiq / ci'
  require('mini.ai').setup {
    -- `aa`/`ii` instead of `an`/`in`: avoid the built-in incremental selection mappings on Neovim >= 0.12 (`:help treesitter-incremental-selection`)
    mappings = {
      around_next = 'aa',
      inside_next = 'ii',
    },
    n_lines = 500,
  }

  require('config.statusline').setup()
end

-- ============================================================
-- Search & navigation: telescope
-- ============================================================
do
  ---@type (string|vim.pack.Spec)[]
  local telescope_plugins = {
    gh 'nvim-lua/plenary.nvim',
    gh 'nvim-telescope/telescope.nvim',
    gh 'nvim-telescope/telescope-ui-select.nvim',
    gh 'nvim-telescope/telescope-live-grep-args.nvim',
  }
  if vim.fn.executable 'make' == 1 then table.insert(telescope_plugins, gh 'nvim-telescope/telescope-fzf-native.nvim') end
  vim.pack.add(telescope_plugins)

  local lga_actions = require 'telescope-live-grep-args.actions'
  require('telescope').setup {
    extensions = {
      ['ui-select'] = { require('telescope.themes').get_dropdown() },
      live_grep_args = {
        mappings = {
          i = {
            ['<C-k>'] = lga_actions.quote_prompt(),
          },
        },
      },
    },
  }

  pcall(require('telescope').load_extension, 'fzf')
  pcall(require('telescope').load_extension, 'ui-select')
  pcall(require('telescope').load_extension, 'live_grep_args')

  local builtin = require 'telescope.builtin'
  vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
  vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })

  -- Files/grep pickers with in-picker toggles (keeps the typed text):
  --  <M-h> toggle hidden files (on by default), <M-i> include git-ignored files
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'

  local function toggle_title(base, o)
    local flags = {}
    if o.hidden then table.insert(flags, 'hidden') end
    if o.no_ignore then table.insert(flags, 'no-ignore') end
    return #flags > 0 and (base .. ' (' .. table.concat(flags, ', ') .. ')') or base
  end

  local function toggle_mappings(picker, o)
    return function(bufnr, map)
      local function toggle(key)
        return function()
          local text = action_state.get_current_line()
          actions.close(bufnr)
          picker(vim.tbl_extend('force', o, { [key] = not o[key], default_text = text }))
        end
      end
      for _, mode in ipairs { 'i', 'n' } do
        map(mode, '<M-h>', toggle 'hidden')
        map(mode, '<M-i>', toggle 'no_ignore')
      end
      return true
    end
  end

  local function find_files(o)
    o = vim.tbl_extend('keep', o or {}, { hidden = true })
    local cmd = { 'rg', '--files', '--glob', '!**/.git/*' }
    if o.hidden then table.insert(cmd, '--hidden') end
    if o.no_ignore then table.insert(cmd, '--no-ignore') end
    builtin.find_files {
      find_command = cmd,
      cwd = o.cwd,
      follow = o.follow,
      default_text = o.default_text,
      prompt_title = toggle_title('Find Files', o),
      attach_mappings = toggle_mappings(find_files, o),
    }
  end

  local function live_grep(o)
    o = vim.tbl_extend('keep', o or {}, { hidden = true })
    builtin.live_grep {
      cwd = o.cwd,
      default_text = o.default_text,
      prompt_title = toggle_title('Live Grep', o),
      additional_args = function()
        local args = { '--glob', '!**/.git/*' }
        if o.hidden then table.insert(args, '--hidden') end
        if o.no_ignore then table.insert(args, '--no-ignore') end
        return args
      end,
      attach_mappings = toggle_mappings(live_grep, o),
    }
  end

  local function live_grep_args(o)
    local ok, lga = pcall(function() return require('telescope').extensions.live_grep_args end)
    if ok then
      lga.live_grep_args { cwd = o and o.cwd or vim.uv.cwd() }
    else
      live_grep(o)
    end
  end

  local function grep_string(o)
    o = vim.tbl_extend('keep', o or {}, { hidden = true })
    -- Resolve the term once so it survives the picker being reopened from visual mode
    o.search = o.search
      or (
        vim.fn.mode():match '[vV\22]' and table.concat(vim.fn.getregion(vim.fn.getpos 'v', vim.fn.getpos '.', { type = vim.fn.mode() }), '\n')
        or vim.fn.expand '<cword>'
      )
    builtin.grep_string {
      cwd = o.cwd,
      search = o.search,
      default_text = o.default_text,
      prompt_title = toggle_title('Grep String', o),
      additional_args = function()
        local args = { '--glob', '!**/.git/*' }
        if o.hidden then table.insert(args, '--hidden') end
        if o.no_ignore then table.insert(args, '--no-ignore') end
        return args
      end,
      attach_mappings = toggle_mappings(grep_string, o),
    }
  end

  vim.keymap.set('n', '<leader>sf', find_files, { desc = '[S]earch [F]iles' })
  vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
  -- Opens live_grep_args prefilled with the word/selection (quoted), so flags like `--iglob` / `-t lua` can be appended
  vim.keymap.set({ 'n', 'v' }, '<leader>sw', function()
    local ok, shortcuts = pcall(require, 'telescope-live-grep-args.shortcuts')
    if not ok then return grep_string() end
    local opts = { cwd = vim.uv.cwd() }
    if vim.fn.mode():match '[vV\22]' then
      shortcuts.grep_visual_selection(opts)
    else
      shortcuts.grep_word_under_cursor(opts)
    end
  end, { desc = '[S]earch current [W]ord (args)' })
  vim.keymap.set('n', '<leader>sg', function() live_grep_args { cwd = vim.uv.cwd() } end, { desc = '[S]earch by [G]rep (args)' })
  vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
  vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
  vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
  vim.keymap.set('n', '<leader>sC', function() builtin.colorscheme { enable_preview = true } end, { desc = '[S]earch [C]olorschemes' })
  vim.keymap.set('n', '<leader>sc', builtin.commands, { desc = '[S]earch [C]ommands' })
  vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })

  -- Telescope-based LSP pickers, mapped when an LSP attaches to a buffer
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('telescope-lsp-attach', { clear = true }),
    callback = function(event)
      local buf = event.buf

      vim.keymap.set('n', 'grr', builtin.lsp_references, { buffer = buf, desc = '[G]oto [R]eferences' })
      vim.keymap.set('n', 'gri', builtin.lsp_implementations, { buffer = buf, desc = '[G]oto [I]mplementation' })
      vim.keymap.set('n', 'grd', builtin.lsp_definitions, { buffer = buf, desc = '[G]oto [D]efinition' })
      vim.keymap.set('n', 'grt', builtin.lsp_type_definitions, { buffer = buf, desc = '[G]oto [T]ype Definition' })
      vim.keymap.set('n', 'gO', builtin.lsp_document_symbols, { buffer = buf, desc = 'Open Document Symbols' })
      vim.keymap.set('n', 'gW', builtin.lsp_dynamic_workspace_symbols, { buffer = buf, desc = 'Open Workspace Symbols' })
      vim.keymap.set({ 'n', 'i' }, 'grI', vim.lsp.buf.signature_help, { buffer = buf, desc = 'Show signature / overloads' })
    end,
  })

  vim.keymap.set(
    'n',
    '<leader>/',
    function() builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown { winblend = 10, previewer = false }) end,
    { desc = '[/] Fuzzily search in current buffer' }
  )

  vim.keymap.set(
    'n',
    '<leader>s/',
    function()
      builtin.live_grep {
        grep_open_files = true,
        prompt_title = 'Live Grep in Open Files',
      }
    end,
    { desc = '[S]earch [/] in Open Files' }
  )

  vim.keymap.set('n', '<leader>sn', function() find_files { cwd = vim.fn.stdpath 'config', follow = true } end, { desc = '[S]earch [N]eovim files' })
end

-- ============================================================
-- LSP: servers, keymaps, Mason
-- ============================================================
do
  vim.pack.add { gh 'j-hui/fidget.nvim' }
  require('fidget').setup {}

  -- Make .NET findable even when nvim is launched with a minimal PATH (e.g. from a GUI)
  do
    local function existing_dir(dir)
      dir = vim.fn.expand(dir)
      return vim.fn.isdirectory(dir) == 1 and dir or nil
    end

    vim.env.DOTNET_ROOT = vim.env.DOTNET_ROOT or existing_dir '/usr/local/share/dotnet' or existing_dir '~/.dotnet'

    local on_path = vim.split(vim.env.PATH or '', ':', { plain = true })
    for _, dir in ipairs { vim.env.DOTNET_ROOT or '', '~/.dotnet/tools' } do
      dir = dir ~= '' and existing_dir(dir) or nil
      if dir and not vim.tbl_contains(on_path, dir) then vim.env.PATH = vim.env.PATH .. ':' .. dir end
    end
  end

  local attach_group = vim.api.nvim_create_augroup('lsp-attach', { clear = true })
  local highlight_group = vim.api.nvim_create_augroup('lsp-highlight', { clear = true })

  -- Per-buffer LSP keymaps and features, set up each time a server attaches
  vim.api.nvim_create_autocmd('LspAttach', {
    group = attach_group,
    callback = function(event)
      local map = function(keys, func, desc, mode)
        mode = mode or 'n'
        vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
      end

      -- Preview the rename inline (inc-rename.nvim)
      vim.keymap.set('n', 'grn', function() return ':IncRename ' .. vim.fn.expand '<cword>' end, { expr = true, buffer = event.buf, desc = '[R]e[n]ame' })

      map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })

      -- Declaration, not definition (e.g. the header in C)
      map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

      -- Highlight references of the word under the cursor while it rests there
      local client = vim.lsp.get_client_by_id(event.data.client_id)
      if client and client:supports_method('textDocument/documentHighlight', event.buf) then
        -- Clear first: a second server attaching to the same buffer would duplicate these
        vim.api.nvim_clear_autocmds { group = highlight_group, buffer = event.buf }
        vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
          buffer = event.buf,
          group = highlight_group,
          callback = vim.lsp.buf.document_highlight,
        })

        vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
          buffer = event.buf,
          group = highlight_group,
          callback = vim.lsp.buf.clear_references,
        })
      end

      if client and client:supports_method('textDocument/inlayHint', event.buf) then
        vim.lsp.inlay_hint.enable(true, { bufnr = event.buf })
        map('<leader>th', function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }) end, '[T]oggle Inlay [H]ints')
      end
    end,
  })

  vim.api.nvim_create_autocmd('LspDetach', {
    group = attach_group,
    callback = function(event)
      vim.lsp.buf.clear_references()
      vim.api.nvim_clear_autocmds { group = highlight_group, buffer = event.buf }
    end,
  })

  -- Servers to enable; Mason installs them (see ensure_installed below)
  ---@type table<string, vim.lsp.Config>
  local servers = {
    clangd = {},
    gopls = {
      settings = {
        gopls = {
          staticcheck = true,
          hints = {
            parameterNames = true,
            assignVariableTypes = true,
          },
        },
      },
    },
    basedpyright = {
      settings = {
        basedpyright = {
          analysis = {
            autoSearchPaths = true,
            inlayHints = {
              variableTypes = true,
              callArgumentNames = true,
              functionReturnTypes = true,
            },
          },
        },
      },
    },
    ruff = {
      on_attach = function(client, _)
        client.server_capabilities.hoverProvider = false -- keep hover/docs from basedpyright
      end,
    },
    tsc = {},
    jsonls = {},

    stylua = {}, -- Used to format Lua code

    -- Lua config as recommended by the Neovim help docs
    lua_ls = {
      on_init = function(client)
        client.server_capabilities.documentFormattingProvider = false -- formatting is done by stylua

        if client.workspace_folders then
          local path = client.workspace_folders[1].name
          if path ~= vim.fn.stdpath 'config' and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc')) then return end
        end

        local current_settings = client.config.settings --[[@as lspconfig.settings.lua_ls]]
        client.config.settings.Lua = vim.tbl_deep_extend('force', current_settings.Lua, {
          runtime = {
            version = 'LuaJIT',
            path = { 'lua/?.lua', 'lua/?/init.lua' },
          },
          workspace = {
            checkThirdParty = false,
            -- Loading the whole runtime is slower; see https://github.com/neovim/nvim-lspconfig/issues/3189
            library = vim.api.nvim_get_runtime_file('', true),
          },
        })
      end,
      ---@type lspconfig.settings.lua_ls
      settings = {
        Lua = {
          format = { enable = false }, -- formatting is done by stylua
        },
      },
    },
  }

  vim.pack.add {
    gh 'neovim/nvim-lspconfig',
    gh 'mason-org/mason.nvim',
    gh 'mason-org/mason-lspconfig.nvim',
    gh 'WhoIsSethDaniel/mason-tool-installer.nvim',
  }

  require('mason').setup {}

  -- Translates between nvim-lspconfig server names and mason.nvim package names (e.g. lua_ls <-> lua-language-server)
  require('mason-lspconfig').setup {
    automatic_enable = false, -- servers are enabled explicitly below
  }

  local ensure_installed = vim.tbl_keys(servers)
  vim.list_extend(ensure_installed, {
    -- Do not repeat anything already in `servers` (e.g. stylua): duplicates make
    -- :MasonToolsUpdateSync wait forever, so `upall` hangs.
    'markdownlint', -- linter run by nvim-lint (lua/plugins/lint.lua)
    'goimports', -- Go formatter (also organizes imports)
    'fsautocomplete', -- F# LSP binary; started by Ionide-vim (lua/plugins/fsharp.lua)
  })

  require('mason-tool-installer').setup { ensure_installed = ensure_installed }

  for name, server in pairs(servers) do
    vim.lsp.config(name, server)
    vim.lsp.enable(name)
  end
end

-- ============================================================
-- Formatting: conform
-- ============================================================
do
  vim.pack.add { gh 'stevearc/conform.nvim' }
  require('conform').setup {
    notify_on_error = false,
    -- Only Go is formatted on save; everything else via <leader>f
    format_on_save = function(bufnr)
      local enabled_filetypes = { go = true }
      if enabled_filetypes[vim.bo[bufnr].filetype] then
        return { timeout_ms = 500 }
      else
        return nil
      end
    end,
    default_format_opts = {
      lsp_format = 'fallback', -- use LSP formatting when no external formatter is configured
    },
    formatters_by_ft = {
      go = { 'goimports' },
    },
  }

  vim.keymap.set({ 'n', 'v' }, '<leader>f', function() require('conform').format { async = true } end, { desc = '[F]ormat buffer' })
end

-- ============================================================
-- Completion & snippets: blink.cmp, LuaSnip
-- ============================================================
do
  vim.pack.add { { src = gh 'L3MON4D3/LuaSnip', version = vim.version.range '2.*' } }
  require('luasnip').setup {}

  vim.pack.add { { src = gh 'saghen/blink.cmp', version = vim.version.range '1.*' } }
  require('blink.cmp').setup {
    keymap = {
      -- super-tab: <Tab> accepts the completion (or jumps within a snippet), <S-Tab> goes back.
      -- Also: <C-space> menu/docs, <C-n>/<C-p> select, <C-e> hide, <C-k> signature help.
      preset = 'super-tab',
    },

    appearance = {
      nerd_font_variant = 'mono',
    },

    completion = {
      documentation = { auto_show = false, auto_show_delay_ms = 500 },
    },

    sources = {
      default = { 'lsp', 'path', 'snippets' },
    },

    snippets = { preset = 'luasnip' },

    -- Lua matcher: avoids downloading a prebuilt Rust binary
    fuzzy = { implementation = 'lua' },

    -- Built-in signature help (lsp_signature.nvim crashes on Neovim 0.12). <C-k> toggles it.
    signature = { enabled = true, window = { border = 'rounded' } },
  }
end

-- ============================================================
-- Treesitter: parsers, highlighting, folds, indentation
-- ============================================================
do
  vim.pack.add { { src = gh 'nvim-treesitter/nvim-treesitter', version = 'main' } }

  local parsers = { 'bash', 'c', 'diff', 'html', 'jinja', 'json', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc', 'c_sharp' }
  require('nvim-treesitter').install(parsers)

  ---@param buf integer
  ---@param language string
  local function treesitter_try_attach(buf, language)
    if not vim.treesitter.language.add(language) then return end
    vim.treesitter.start(buf, language)

    vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
    vim.wo.foldmethod = 'expr'

    -- Without an indent query, indentexpr falls back to Vim's built-in indenting
    local has_indent_query = vim.treesitter.query.get(language, 'indents') ~= nil
    if has_indent_query then vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" end
  end

  local available_parsers = require('nvim-treesitter').get_available()
  vim.api.nvim_create_autocmd('FileType', {
    callback = function(args)
      local buf, filetype = args.buf, args.match

      local language = vim.treesitter.language.get_lang(filetype)
      if not language then return end

      local installed_parsers = require('nvim-treesitter').get_installed 'parsers'

      if vim.tbl_contains(installed_parsers, language) then
        treesitter_try_attach(buf, language)
      elseif vim.tbl_contains(available_parsers, language) then
        -- Auto-install the parser, then enable it
        require('nvim-treesitter').install(language):await(function() treesitter_try_attach(buf, language) end)
      else
        -- The parser may exist even though nvim-treesitter doesn't provide it
        treesitter_try_attach(buf, language)
      end
    end,
  })
end

-- ============================================================
-- Per-plugin modules: lua/plugins/*.lua
-- ============================================================
-- Loaded in alphabetical order, after the sections above (some modules rely on
-- mini.nvim, mason.nvim, plenary.nvim and telescope being installed already).
for _, file in ipairs(vim.fn.glob(vim.fn.stdpath 'config' .. '/lua/plugins/*.lua', false, true)) do
  require('plugins.' .. vim.fn.fnamemodify(file, ':t:r'))
end

-- vim: ts=2 sts=2 sw=2 et
