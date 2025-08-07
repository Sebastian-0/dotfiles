--
-- NOTE: Language servers must be installed in plugins.lua using their real name,
--       in the below configuration we use the nvim lsp-config names instead, and
--       these are USUALLY not the same! You can find the real name in lsp-configs'
--       default config section for the LSP, under cmd.
--
--       See lsp-configs here: https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md
--
--
-- Configure LSPs
local lspconfig = require("lspconfig")
vim.lsp.config('clangd', {
    cmd = {"clangd", "--clang-tidy", "--background-index"}
    -- on_attach = function()
    --     vim.keymap.set("n", "gF", ":LspClangdSwitchSourceHeader<CR>")
    -- end
})
vim.lsp.config('lua_ls', {
    settings = {
        -- LuaFormatter off
        Lua = {
            workspace = {
                checkThirdParty = false,
            }
        }
        -- LuaFormatter on
    }
})
vim.lsp.config('pylsp', {
    settings = {
        -- LuaFormatter off
        pylsp = {
            plugins = {
                pycodestyle = {
                    ignore = {'E501', 'E203', 'W503'},
                },
                mccabe = {
                    enabled = false,
                },
                pylint = {
                    enabled = false,
                    args = {"--disable=missing-class-docstring,missing-function-docstring"}
                },
            }
        }
        -- LuaFormatter on
    }
})
vim.lsp.config('rust_analyzer', {
    settings = {
        -- LuaFormatter off
        ["rust-analyzer"] = {
            check = {
                command = "clippy",
                extraArgs = {"--", "-W", "clippy::pedantic"},
                checkOnSave = true,
            }
        },
        -- LuaFormatter on
    }
})

-- Enable LSPs
vim.lsp.enable('bashls')
vim.lsp.enable('clangd')
vim.lsp.enable('cmake')
vim.lsp.enable('dockerls')
vim.lsp.enable('glslls')
vim.lsp.enable('html')
vim.lsp.enable('lua_ls')
vim.lsp.enable('pylsp')
vim.lsp.enable('rust_analyzer')
vim.lsp.enable('ts_ls')
vim.lsp.enable('zls')

-- Keymaps (most are defined by telescope, here are extra)
-- TODO: This should only be active for Clangd, and right now it's not obvious
--       how to make that happen... Overriding on_attach means the default
--       on_attach gets deleted!
vim.keymap.set("n", "gF", ":LspClangdSwitchSourceHeader<CR>")
-- TODO: This should only be active for rust analyzer
vim.keymap.set("n", "gR", ":LspCargoReload<CR>")
