-- F# support: fsautocomplete LSP (auto-enabled as the `ionide` config) + F# Interactive.
-- FSI: <M-CR> send line/selection, <M-@> toggle FSI window, :FsiEvalBuffer, :FsiReset.
-- The fsautocomplete binary is installed by Mason (see ensure_installed in init.lua).

vim.g['fsharp#lsp_recommended_colorscheme'] = 0 -- keep my own diagnostic highlights
vim.g['fsharp#fsi_window_command'] = 'botright 15new'

vim.pack.add { 'https://github.com/ionide/Ionide-vim' }
