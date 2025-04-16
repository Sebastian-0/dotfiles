vim.lsp.config('*', {
    -- TODO What is multilineTokenSupport?
    -- capabilities = {
    --   textDocument = {
    --     semanticTokens = {
    --       multilineTokenSupport = true,
    --     }
    --   }
    -- },
    root_markers = {'.git'}
})

vim.lsp.config['bash-language-server'] = {cmd = {'bash-language-server', 'start'}, filetypes = {'bash', 'sh'}}
vim.lsp.enable('bash-language-server')

vim.lsp.config['clangd'] = {
    cmd = {"clangd", "--clang-tidy", "--background-index"},
    filetypes = {"c", "cpp", "objc", "objcpp", "cuda", "proto"},
    root_markers = {
        ".git",
        ".clangd",
        ".clang-tidy",
        ".clang-format",
        "compile_commands.json",
        "compile_flags.txt",
        "configure.ac"
    }
}
vim.lsp.enable('clangd')

vim.lsp.config['cmake-language-server'] = {cmd = {'cmake-language-server'}, filetypes = {'cmake'}}
vim.lsp.enable('cmake-language-server')

vim.lsp.config['docker-langserver'] = {cmd = {'docker-langserver', '--stdio'}, filetypes = {'dockerfile'}}
vim.lsp.enable('docker-langserver')

vim.lsp.config['glslls'] = {
    cmd = {'glslls', '--stdin'},
    filetypes = {"glsl", "vert", "tesc", "tese", "frag", "geom", "comp"}
}
vim.lsp.enable('glslls')

vim.lsp.config['vscode-html-language-server'] = {
    cmd = {'vscode-html-language-server', '--stdio'},
    filetypes = {'html', 'xhtml'},
    root_markers = {'.git', 'package.json'}
}
vim.lsp.enable('vscode-html-language-server')

vim.lsp.config['lua-language-server'] = {
    cmd = {'lua-language-server'},
    filetypes = {'lua'},
    root_markers = {'.git', '.luarc.json', '.luarc.jsonc'},
    -- LuaFormatter off
    settings = {
        Lua = {
            workspace = {
                checkThirdParty = false,
            }
        }
    }
    -- LuaFormatter on
}
vim.lsp.enable('lua-language-server')

vim.lsp.config['pylsp'] = {
    cmd = {'pylsp'},
    filetypes = {'python'},
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
}
vim.lsp.enable('pylsp')

vim.lsp.config['rust-analyzer'] = {
    cmd = {'rust-analyzer'},
    filetypes = {'rust'},
    root_markers = {'Cargo.lock'},
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
}
vim.lsp.enable('rust-analyzer')

vim.lsp.config['typescript-language-server'] = {
    cmd = {'typescript-language-server', '--stdio'},
    filetypes = {"javascript", "javascriptreact", "javascript.jsx", "typescript", "typescriptreact", "typescript.tsx"},
    root_markers = {".git", "tsconfig.json", "jsconfig.json", "package.json"}
}
vim.lsp.enable('typescript-language-server')
