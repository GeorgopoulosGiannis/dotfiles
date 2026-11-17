# Neovim config

Personal Neovim configuration, derived from
[kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) (MIT, see `LICENSE.md`).
Managed with chezmoi alongside the rest of my dotfiles.

## Requirements

- Neovim **>= 0.12** (plugins are managed by the built-in `vim.pack`)
- `git`, `make`, `unzip`, [`ripgrep`](https://github.com/BurntSushi/ripgrep), a C compiler
- A [Nerd Font](https://www.nerdfonts.com/)
- Optional per language: `go`, `node`/`npm`, `dotnet`, `python`

Run `:checkhealth config` to verify the basics.

## Layout

| Path                    | Purpose                                                              |
| ----------------------- | -------------------------------------------------------------------- |
| `init.lua`              | Options, core keymaps, LSP, completion, treesitter, telescope, UI    |
| `lua/plugins/*.lua`     | One module per smaller plugin or feature, loaded alphabetically      |
| `lua/config/health.lua` | `:checkhealth config`                                                |
| `nvim-pack-lock.json`   | Committed `vim.pack` lockfile: plugin revisions are pinned           |
| `.stylua.toml`          | Formatting rules (`stylua .`)                                        |

Update plugins with `:lua vim.pack.update()` and commit the changed lockfile.

## Plugins

- **UI**: tokyonight, mini.nvim (icons, statusline, `mini.ai`, indentscope), which-key,
  indent-blankline, todo-comments, fidget, gitsigns, guess-indent, marks, nvim-window-picker
- **Search & navigation**: telescope (+ fzf-native, ui-select, live-grep-args), flash, harpoon,
  neo-tree, grug-far (search and replace), mundo (undo tree)
- **LSP**: nvim-lspconfig, mason (+ lspconfig, tool-installer), inc-rename, blink.cmp, LuaSnip
- **Formatting & linting**: conform (Go formatted on save), nvim-lint
- **Treesitter**: nvim-treesitter, nvim-treesitter-textobjects
- **Editing**: nvim-surround, nvim-autopairs
- **Debugging**: nvim-dap, nvim-dap-ui, nvim-dap-go, mason-nvim-dap
- **Languages**: easy-dotnet (C#/.NET), Ionide-vim (F#), venv-selector (Python),
  render-markdown and markdown-preview (Markdown)
- **Git & GitHub**: gitsigns, diffview, octo
- **Databases**: vim-dadbod (+ ui, completion)

## Keymaps

Leader is `<Space>`; which-key shows the available chains.

| Keys              | Group                                                          |
| ----------------- | -------------------------------------------------------------- |
| `<leader>s…`      | Search (telescope): files, grep, word, diagnostics, resume     |
| `<leader>g…`      | Git hunks (gitsigns); `<leader>t…` toggles (blame, inlay hints)|
| `<leader>h…`, `1-4` | Harpoon: add/menu/remove, jump to file 1-4                   |
| `gr…`             | LSP: rename, code action, references, implementation, type     |
| `<F5>`, `<F9>`, `<leader>d…` | Debugging and .NET (run/debug)                      |
| `<leader>m…`      | Markdown rendering and browser preview                         |
| `s`, `gs`         | Flash jump / treesitter selection                              |
| `am`/`im`, `ac`/`ic`, `aS` | Treesitter text objects: method, class, local scope   |
| `\`               | Toggle the file tree                                           |
| `<leader>u`       | Undo tree                                                      |

## Credits

Started from [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) by
TJ DeVries and contributors.
