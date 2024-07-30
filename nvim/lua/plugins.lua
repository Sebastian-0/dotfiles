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
        version = '0.1.x',
        dependencies = {
            {
                'nvim-lua/plenary.nvim',
                version = '0.1.4'
            }
        },
        config = function()
            local builtin = require('telescope.builtin')
            vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
            vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
            vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
            vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})
            vim.keymap.set('n', '<leader>fr', builtin.resume, {})

            require('telescope').setup {
                pickers = {
                    find_files = {
                        find_command = { "rg", "--files", "--hidden", "--glob", "!**/.git/*" }
                    },
                    live_grep = {
                        additional_args = { "--hidden", "--glob", "!**/.git/*", "--glob", "!*.lock" }
                    }
                }
            }
        end
    },
    {
        "nvim-treesitter/nvim-treesitter",
        version = '0.9.x',
        build = ":TSUpdate",
        config = function()
            local configs = require("nvim-treesitter.configs")

            configs.setup({
                ensure_installed = { "cuda", "c", "cpp", "cmake", "lua", "vim", "python", "typescript", "tsx", "bash",
                    "javascript", "rust", "java", "yaml" },
                sync_install = false,
                highlight = { enable = true, additional_vim_regex_highlighting = { "python" } }, -- Python regex highlight is a fix for https://github.com/nvim-treesitter/nvim-treesitter/discussions/1951
                -- indent = { enable = true },
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
                },
                -- custom_highlights = function(colors)
                --     return {
                --         CursorColumn = { bg = colors.surface0 }
                --     }
                -- end
            }
        end
    },
    {
        'nvim-lualine/lualine.nvim',
        commit='0a5a668',
        dependencies = {
            {
                'nvim-tree/nvim-web-devicons',
                commit = 'b77921f'
            }
        },
        config = function()
            require("lualine").setup {
                options = {
                    theme = "catppuccin"
                }, sections = {
                lualine_a = { 'mode' },
                lualine_b = { 'branch', 'diff', 'diagnostics' },
                lualine_c = { 'filename' },
                lualine_x = { 'os.date("%d %b %H:%M")', 'encoding', 'fileformat', 'filetype' },
                lualine_y = { 'progress' },
                lualine_z = { 'location' }
            },
            }
        end
    },
    {
        "karb94/neoscroll.nvim",
        commit = 'af764ab',
        opts = {
            stop_eof = false,
            easing_function = "quadratic",
        }
    },
    {
        "terrortylor/nvim-comment",
        commit = 'e9ac16a',
        config = function()
            require("nvim_comment").setup()
        end
    },
    {
        "ryanoasis/vim-devicons",
        version = '0.11.x',
    },
    {
        "lambdalisue/suda.vim",
        version = "1.2.x"
    },
    {
        "Vimjas/vim-python-pep8-indent",
        commit = '60ba5e1',
        ft = "python"
    },
    {
        "kylechui/nvim-surround",
        version = "2.1.x",
        event = "VeryLazy",
        config = function()
            require("nvim-surround").setup({})
        end
    },
    {
        "nvim-neo-tree/neo-tree.nvim",
        branch = "v3.x",
        dependencies = {
            {
                'nvim-lua/plenary.nvim',
                version = '0.1.4'
            },
            {
                'nvim-tree/nvim-web-devicons',
                commit = 'b77921f'
            },
            {
                "MunifTanjim/nui.nvim",
                version = '0.3.x'
            }
        },
        config = function()
            require("neo-tree").setup({
                window = {
                    position = "current",
                    mappings = {
                        ["l"] = "open"
                    }
                },
                filesystem = {
                    hijack_netrw_behavior = "open_default"
                },
                event_handlers = {
                    {
                        event = "neo_tree_buffer_enter",
                        handler = function(_)
                            vim.opt.relativenumber = true
                            vim.opt.number = true
                        end,
                    }
                },
            })
            vim.api.nvim_create_user_command("Ex", "Neotree", {}) -- Unclear why this is needed... I thought the hijack setting should deal with this...
        end
    },
    {
        "lewis6991/gitsigns.nvim",
        version = "0.8.x",
        config = function()
            require('gitsigns').setup({
                current_line_blame = true,
                current_line_blame_opts = {
                    delay = 500
                },
                on_attach = function(_)
                    local gs = package.loaded.gitsigns
                    vim.keymap.set('n', '<leader>hd', gs.diffthis)
                end
            })
        end
    },
    {
        "rhysd/git-messenger.vim",
        commit = '8a61bdf',
        init = function()
            vim.g.git_messenger_no_default_mappings = true
            vim.g.git_messenger_always_into_popup = true
            vim.keymap.set('n', '<leader>hb', ':GitMessenger<CR>')
        end
    },
    {
        "folke/neodev.nvim",
        version = "2.5.x",
        opts = {},
        lazy = false,
        priority = 51
    },
    {
        'VonHeikemen/lsp-zero.nvim',
        branch = 'v3.x',
        dependencies = {
            {
                'williamboman/mason.nvim',
                version = '1.10.x'
            },
            {
                'williamboman/mason-lspconfig.nvim',
                version = '1.29.x'
            },
            {
                'neovim/nvim-lspconfig',
                version = '0.1.8'
            },
            {
                'hrsh7th/nvim-cmp',
                commit = '5260e5e'
            },
            {
                'hrsh7th/cmp-path',
                commit = '91ff86c'
            },
            {
                'hrsh7th/cmp-nvim-lsp',
                commit = '39e2eda'
            },
            {
                'L3MON4D3/LuaSnip',
                version = '2.3.x'
            },
        },
        config = function()
            local lsp_zero = require('lsp-zero')

            lsp_zero.on_attach(function(_, bufnr)
                lsp_zero.default_keymaps({ buffer = bufnr })
            end)

            require('mason').setup({})
            require('mason-lspconfig').setup({
                ensure_installed = {
                    'tsserver',
                    'rust_analyzer',
                    'pylsp',
                    'clangd',
                    'lua_ls',
                    'bashls',
                    'cmake',
                    'dockerls'
                },
                handlers = {
                    lsp_zero.default_setup,
                },
            })

            require("lspconfig").rust_analyzer.setup {
                settings = {
                    ["rust-analyzer"] = {
                        check = {
                            command = "clippy",
                            extraArgs = {"--", "-W", "clippy::pedantic"},
                            checkOnSave = true,
                        }
                    },
                }
            }

            require("lspconfig").pylsp.setup {
                settings = {
                    pylsp = {
                        plugins = {
                            pycodestyle = {
                                ignore = { 'E501', 'E203', 'W503' },
                            },
                            mccabe = {
                                enabled = false,
                            },
                        }
                    }
                }
            }

            require("lspconfig").lua_ls.setup {
                settings = {
                    Lua = {
                        workspace = {
                            checkThirdParty = false,
                        }
                    }
                }
            }
            local has_words_before = function()
                unpack = unpack or table.unpack
                local line, col = unpack(vim.api.nvim_win_get_cursor(0))
                return col ~= 0 and
                    vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
            end
            local luasnip = require('luasnip')
            local cmp = require('cmp')
            cmp.setup({
                sources = cmp.config.sources({
                    { name = "nvim_lsp" },
                    { name = "luasnip" },
                    { name = 'path' }
                }),
                mapping = cmp.mapping.preset.insert({
                    ["<Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_next_item()
                            -- You could replace the expand_or_jumpable() calls with expand_or_locally_jumpable()
                            -- they way you will only jump inside the snippet region
                        elseif luasnip.expand_or_jumpable() then
                            luasnip.expand_or_jump()
                        elseif has_words_before() then
                            cmp.complete()
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                    ["<S-Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_prev_item()
                        elseif luasnip.jumpable(-1) then
                            luasnip.jump(-1)
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                    ['<CR>'] = cmp.mapping.confirm({ select = true }),
                    ['<C-Space>'] = cmp.mapping.complete(),
                })
            })
        end
    },
})

-- Enable theme
vim.cmd.colorscheme "catppuccin"
