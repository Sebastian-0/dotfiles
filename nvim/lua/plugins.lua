local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local out = vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", -- latest stable release
        lazypath
    })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            {"Failed to clone lazy.nvim:\n", "ErrorMsg"},
            {out, "WarningMsg"},
            {"\nPress any key to exit..."}
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
    end
end
vim.opt.rtp:prepend(lazypath)

-- Load plugins
require("lazy").setup({
    {
        'nvim-telescope/telescope.nvim',
        -- version = '0.1.x',
        commit = '5899106',
        dependencies = {
            {'nvim-lua/plenary.nvim', version = '0.1.4'},
            {"nvim-telescope/telescope-live-grep-args.nvim", commit = "b80ec2c"}
        },
        config = function()
            -- File search keymaps
            local builtin = require('telescope.builtin')
            vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
            vim.keymap.set('n', '<leader>fF', function()
                builtin.find_files({no_ignore = true})
            end, {})
            vim.keymap.set("n", "<leader>fg", require('telescope').extensions.live_grep_args.live_grep_args)
            vim.keymap.set("n", "<leader>fG", function()
                require('telescope').extensions.live_grep_args.live_grep_args({additional_args = {'--no-ignore'}})
            end)
            vim.keymap.set('n', '<leader>fb', builtin.buffers, {})

            -- LSP keymaps
            vim.keymap.set("n", "grr", builtin.lsp_references)
            vim.keymap.set("n", "gD", builtin.lsp_type_definitions)
            vim.keymap.set("n", "gd", builtin.lsp_definitions)
            vim.keymap.set("n", "gh", builtin.lsp_incoming_calls)
            vim.keymap.set("n", "gO", builtin.lsp_document_symbols)
            vim.keymap.set("n", "<leader>gl", function()
                builtin.diagnostics({bufnr = 0})
            end)

            -- Git keymaps
            vim.keymap.set("n", "<leader>gs", builtin.git_stash)
            vim.keymap.set("n", "<leader>gb", builtin.git_branches)
            vim.keymap.set("n", "<leader>gc", builtin.git_bcommits)

            -- Misc
            vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})
            vim.keymap.set('n', '<leader>fr', builtin.resume, {})

            local prompt_toggle = function(option)
                local action_state = require("telescope.actions.state")
                return function(prompt_bufnr)
                    local picker = action_state.get_current_picker(prompt_bufnr)
                    local prompt = picker:_get_prompt()
                    prompt = vim.trim(prompt)

                    if prompt:find("\"") == nil and prompt:find("'") == nil then
                        local helpers = require("telescope-live-grep-args.helpers")
                        prompt = helpers.quote(prompt, {quote_char = "\""})
                    end

                    local idx = prompt:find(option, 1, true)
                    if idx then
                        prompt = prompt:sub(1, idx - 1) .. prompt:sub(idx + option:len())
                    else
                        prompt = prompt .. " " .. option
                    end

                    picker:set_prompt(vim.trim(prompt))
                end
            end

            local telescope = require('telescope')
            local lga_actions = require("telescope-live-grep-args.actions")
            telescope.setup {
                pickers = {
                    find_files = {
                        hidden = true,
                        find_command = {"rg", "--files", "--color", "never", "--glob", "!**/.git/*"},
                        mappings = {i = {["<C-Space>"] = require('telescope.actions').to_fuzzy_refine}}
                    },
                    live_grep = { -- Currently not used because we use live_grep_args
                        glob_pattern = {"!**/.git/*", "!*.lock"},
                        additional_args = {"--hidden"},
                        mappings = {i = {["<C-Space>"] = require('telescope.actions').to_fuzzy_refine}}
                    }
                },
                extensions = {
                    live_grep_args = {
                        mappings = {
                            i = {
                                ["<C-a>"] = lga_actions.quote_prompt(),
                                ["<C-h>"] = prompt_toggle("--no-hidden"),
                                ["<C-i>"] = prompt_toggle("--no-ignore"),
                                ["<C-Space>"] = require('telescope.actions').to_fuzzy_refine
                            }
                        },
                        additional_args = {"--hidden", "--glob", "!**/.git/*", "--glob", "!*.lock"}
                    }
                }
            }
            telescope.load_extension("live_grep_args")
        end
    },
    {
        "nvim-treesitter/nvim-treesitter",
        -- version = '0.9.x',
        commit = '5774e7d',
        build = ":TSUpdate",
        config = function()
            local configs = require("nvim-treesitter.configs")

            configs.setup({
                ensure_installed = {
                    "bash",
                    "c",
                    "c_sharp",
                    "cmake",
                    "cpp",
                    "cuda",
                    "dockerfile",
                    "glsl",
                    "java",
                    "javascript",
                    "lua",
                    "python",
                    "rust",
                    "tsx",
                    "typescript",
                    "vim",
                    "yaml",
                    "zig"
                },
                modules = {},
                ignore_install = {},
                sync_install = false,
                auto_install = false, -- NOTE: Requires that you have the treesitter cli installed
                highlight = {enable = true, additional_vim_regex_highlighting = {"python"}} -- Python regex highlight is a fix for https://github.com/nvim-treesitter/nvim-treesitter/discussions/1951
                -- indent = { enable = true },
            })
        end
    },
    {
        "catppuccin/nvim",
        name = "catppuccin",
        priority = 1000,
        opts = {
            integrations = {
                treesitter = true,
                telescope = {
                    enabled = true
                    -- style = "nvchad"
                }
            }
            -- custom_highlights = function(colors)
            --     return {
            --         CursorColumn = { bg = colors.surface0 }
            --     }
            -- end
        }
    },
    {
        'nvim-lualine/lualine.nvim',
        commit = 'f4f791f',
        dependencies = {{'nvim-tree/nvim-web-devicons', commit = '1020869'}},
        opts = {
            options = {theme = "catppuccin"},
            sections = {
                lualine_a = {'mode'},
                lualine_b = {'diff', 'diagnostics'},
                lualine_c = {'filename'},
                lualine_x = {'os.date("%d %b %H:%M")', 'encoding', 'fileformat', {'filetype', icon_only = true}},
                lualine_y = {'progress'},
                lualine_z = {'location'}
            }
        }
    },
    {"kylechui/nvim-surround", version = "2.3.x", event = "VeryLazy", opts = {}},
    {
        "nvim-neo-tree/neo-tree.nvim",
        branch = "v3.x",
        dependencies = {
            {'nvim-lua/plenary.nvim', version = '0.1.4'},
            {'nvim-tree/nvim-web-devicons', commit = '1020869'},
            {"MunifTanjim/nui.nvim", version = '0.3.x'}
        },
        opts = {
            window = {position = "current", mappings = {["l"] = "open"}},
            filesystem = {hijack_netrw_behavior = "open_default"},
            event_handlers = {
                {
                    event = "neo_tree_buffer_enter",
                    handler = function(_)
                        vim.opt.relativenumber = true
                        vim.opt.number = true
                    end
                }
            }
        },
        init = function()
            vim.api.nvim_create_user_command("Ex", "Neotree", {}) -- Unclear why this is needed... I thought the hijack setting should deal with this...
        end
    },
    {
        "lewis6991/gitsigns.nvim",
        version = "1.0.x",
        opts = {
            current_line_blame = true,
            current_line_blame_opts = {delay = 500},
            on_attach = function(_)
                local gs = package.loaded.gitsigns
                vim.keymap.set('n', '<leader>gd', gs.preview_hunk_inline)
                vim.keymap.set('n', '<leader>gD', gs.diffthis)
                vim.keymap.set('n', '<leader>gw', gs.toggle_word_diff)
                vim.keymap.set('n', '<leader>gn', gs.next_hunk)
                vim.keymap.set('n', '<leader>gN', gs.prev_hunk)
                vim.keymap.set('n', '<leader>gr', gs.reset_hunk)
            end
        }
    },
    {
        "rhysd/git-messenger.vim",
        commit = 'edc603d',
        init = function()
            vim.g.git_messenger_no_default_mappings = true
            vim.g.git_messenger_always_into_popup = true
            vim.keymap.set('n', '<leader>gh', ':GitMessenger<CR>')
        end
    },
    {
        "mbbill/undotree",
        commit = 'b951b87',
        init = function()
            vim.keymap.set('n', '<leader>u', vim.cmd.UndotreeToggle)
            vim.opt.undofile = true
            vim.g.undotree_SetFocusWhenToggle = true
        end
    },
    {"folke/lazydev.nvim", version = "1.9.x", ft = "lua", opts = {}},
    {
        'williamboman/mason.nvim',
        version = '1.11.x',
        dependencies = {{'WhoIsSethDaniel/mason-tool-installer.nvim', commit = '1255518'}},
        config = function()
            require('mason').setup({})
            require('mason-tool-installer').setup {
                -- NOTE: These must be configured and enabled in lsp.lua
                ensure_installed = {
                    'bash-language-server',
                    'clangd',
                    'cmake-language-server',
                    'dockerfile-language-server',
                    'glslls',
                    'html-lsp',
                    'jdtls',
                    'lua-language-server',
                    'python-lsp-server',
                    'rust-analyzer',
                    'typescript-language-server',
                    'zls'
                }
            }
        end
    },
    {'neovim/nvim-lspconfig', commit = 'bd1d024'},
    {
        'hrsh7th/nvim-cmp',
        commit = '1250990',
        dependencies = {
            {'hrsh7th/cmp-path', commit = '91ff86c'},
            {'hrsh7th/cmp-nvim-lsp', commit = '99290b3'},
            {'saadparwaiz1/cmp_luasnip', commit = '98d9cb5'},
            {'L3MON4D3/LuaSnip', version = '2.3.x'}
        },
        config = function()
            local has_words_before = function()
                unpack = unpack or table.unpack
                local line, col = unpack(vim.api.nvim_win_get_cursor(0))
                return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") ==
                           nil
            end
            local luasnip = require('luasnip')
            local cmp = require('cmp')
            cmp.setup({
                sources = cmp.config.sources({{name = "nvim_lsp"}, {name = "luasnip"}, {name = 'path'}}),
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
                    end, {"i", "s"}),
                    ["<S-Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_prev_item()
                        elseif luasnip.jumpable(-1) then
                            luasnip.jump(-1)
                        else
                            fallback()
                        end
                    end, {"i", "s"}),
                    ['<CR>'] = cmp.mapping.confirm({select = true}),
                    ['<C-Space>'] = cmp.mapping.complete(),
                    ['<C-d>'] = cmp.mapping.scroll_docs(4),
                    ['<C-u>'] = cmp.mapping.scroll_docs(-4)
                }),
                snippet = { -- I don't know when this is useful...
                    expand = function(args)
                        require('luasnip').lsp_expand(args.body)
                    end
                }
            })

            require("luasnip.loaders.from_lua").load({paths = "./lua/snippets"})
        end
    },
    {
        "rest-nvim/rest.nvim",
        version = "3.12.0",
        dependencies = {
            "nvim-treesitter/nvim-treesitter",
            opts = function(_, opts)
                opts.ensure_installed = opts.ensure_installed or {}
                table.insert(opts.ensure_installed, "http")
            end
        }
    },
    {
        'rmagatti/auto-session',
        commit = '9c3f977',
        lazy = false,
        opts = {args_allow_single_directory = false, close_unsupported_windows = false}
    },
    {"karb94/neoscroll.nvim", commit = 'f957373', opts = {stop_eof = false, easing_function = "quadratic"}},
    {"ryanoasis/vim-devicons", version = '0.11.x'},
    {"lambdalisue/suda.vim", version = "1.2.x"},
    {"Vimjas/vim-python-pep8-indent", commit = '60ba5e1', ft = "python"},
    {"jupyter-vim/jupyter-vim"},
    {
        "norcalli/nvim-colorizer.lua",
        config = function()
            require("colorizer").setup()
        end
    }
})

-- Enable theme
vim.cmd.colorscheme "catppuccin"
