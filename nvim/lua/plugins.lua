local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Load plugins
require("lazy").setup({
    {
        'nvim-telescope/telescope.nvim',
        tag = '0.1.3',
        dependencies = { 'nvim-lua/plenary.nvim' },
        config = function()
            local builtin = require('telescope.builtin')
            vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
            vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
            vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
            vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})
        end
    },
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        config = function()
            local configs = require("nvim-treesitter.configs")

            configs.setup({
                ensure_installed = { "c", "cpp", "cmake", "lua", "vim", "python", "typescript", "tsx", "bash", "javascript", "rust" },
                sync_install = false,
                highlight = { enable = true },
--                indent = { enable = true },  
            })
        end
    },
    {
        "catppuccin/nvim",
        name = "catppuccin",
        priority = 1000,
        config = function()
            require("catppuccin").setup {
                integrations = {
                    treesitter = true,
                    telescope = {
                        enabled = true,
                        -- style = "nvchad"
                    }
                }
        --         custom_highlights = function(colors)
        --             return {
        --                 CursorColumn = { bg = colors.surface0 }
        --             }
        --         end
            }
        end
    },
    {
        'nvim-lualine/lualine.nvim',
        dependencies = { 'nvim-tree/nvim-web-devicons' },
        config = function()
            require("lualine").setup {
                options = {
                    theme = "catppuccin"
                },sections = {
                    lualine_a = {'mode'},
                    lualine_b = {'branch', 'diff', 'diagnostics'},
                    lualine_c = {'filename'},
                    lualine_x = {'os.date("%d %b %H:%M")', 'encoding', 'fileformat', 'filetype'},
                    lualine_y = {'progress'},
                    lualine_z = {'location'}
                },
            }
        end
    },
    {
        "karb94/neoscroll.nvim",
        opts = {
            stop_eof = false,
            easing_function = "quadratic"
        }
    },
    {
        "terrortylor/nvim-comment",
        config = function()
            require("nvim_comment").setup()
        end
    },
    {
        "ryanoasis/vim-devicons",
    }
})

-- Enable theme
vim.cmd.colorscheme "catppuccin"
