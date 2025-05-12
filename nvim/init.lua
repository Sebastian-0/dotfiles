vim.opt.mouse = ""
vim.opt.scrolloff = 5
vim.opt.tabstop = 4
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.breakindent = true
vim.opt.breakindentopt = "shift:2"
vim.opt.wildmode = "longest,list"
vim.opt.ignorecase = true
-- vim.opt.signcolumn = "yes" -- Could also set this to "number"
-- vim.opt.completeopt = "menu" -- I don't notice the difference...

-- Display settings
vim.opt.relativenumber = true
vim.opt.number = true
vim.opt.cursorline = true
-- vim.opt.cursorcolumn = true -- Produces very laggy scrolling
vim.opt.winborder = "rounded"

-- This is only needed for norcalli/nvim-colorizer.lua to work
vim.opt.termguicolors = true

-- Leader
vim.g.mapleader = " "
vim.keymap.set("n", " ", "")

vim.g.netrw_liststyle = 3
vim.g.netrw_altv = 1
vim.g.netrw_winsize = 75
vim.g.netrw_list_hide = "\\(^\\|\\s\\s\\)\\zs\\.\\S\\+" -- Hide all dotfiles by default
-- vim.g.netrw_browsex_viewer = "xdg-open" -- Controls what happens when pressing x over files, for some reason not working...
vim.g.netrw_bufsettings = "noma nomod nobl nowrap ro number relativenumber"

-- Return to previous position when opening a file
vim.api.nvim_create_autocmd("BufReadPost", {
    group = vim.api.nvim_create_augroup("ReturnToLast", {clear = true}),
    command = [[if line("'\"") > 1 && line("'\"") <= line("$") | execute "normal! g'\"" | endif]]
})

-- Stop automatic comments
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("NoAutoComment", {clear = true}),
    callback = function()
        vim.opt.formatoptions:remove({"o", "r"})
    end
})

-- Set filetype for glsl
vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
    group = vim.api.nvim_create_augroup("GlslLangType", {clear = true}),
    pattern = {"*.frag", "*.vert", "*.fs", "*.vs"},
    command = [[set filetype=glsl]]
})

-- Set comment character for certain file types
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("CommentString", {clear = true}),
    pattern = {"c", "cpp", "cuda", "glsl"},
    command = [[setlocal commentstring=//\ %s]]
})

-- Add column showing maximum width for commit bodies
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("GitCommitBodyMarker", {clear = true}),
    pattern = "gitcommit",
    callback = function()
        vim.opt.textwidth = 72
        vim.opt.colorcolumn = "73"
    end
})

-- Managing diagnostics
vim.keymap.set('n', 'gl', '<cmd>lua vim.diagnostic.open_float()<cr>', {desc = 'Open diagnostics in floating'})
vim.keymap.set('n', '[d', '<cmd>lua vim.diagnostic.goto_prev()<cr>', {desc = 'Go to previous diagnostic'})
vim.keymap.set('n', ']d', '<cmd>lua vim.diagnostic.goto_next()<cr>', {desc = 'Go to next diagnostic'})

-- Moving lines of code
vim.keymap.set("n", "<a-j>", ":m .+1<CR>==")
vim.keymap.set("n", "<a-k>", ":m .-2<CR>==")
vim.keymap.set("i", "<a-j>", "<Esc>:m .+1<CR>==gi")
vim.keymap.set("i", "<a-k>", "<Esc>:m .-2<CR>==gi")
vim.keymap.set("v", "<a-j>", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "<a-k>", ":m '<-2<CR>gv=gv")

vim.keymap.set("n", "<a-down>", "<a-j>", {remap = true})
vim.keymap.set("n", "<a-up>", "<a-k>", {remap = true})
vim.keymap.set("i", "<a-down>", "<a-j>", {remap = true})
vim.keymap.set("i", "<a-up>", "<a-k>", {remap = true})
vim.keymap.set("v", "<a-down>", "<a-j>", {remap = true})
vim.keymap.set("v", "<a-up>", "<a-k>", {remap = true})

-- Center view when jumping
-- vim.keymap.set("n", "<C-d>", "<C-d>zz")  -- These doesn't work with neoscroll enabled...
-- vim.keymap.set("n", "<c-u>", "<C-u>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- Jump back after reindenting
vim.keymap.set("n", "=ap", "ma =ap `a")

-- Make Y copy rest of line
vim.keymap.set("n", "Y", "y$")

-- Move up/down visual editor lines (when lines are auto wrapped)
local function smart_j()
    return vim.v.count == 0 and "gj" or "j"
end

local function smart_k()
    return vim.v.count == 0 and "gk" or "k"
end

vim.keymap.set("n", "j", smart_j, {expr = true})
vim.keymap.set("n", "k", smart_k, {expr = true})

-- Extra save and quit commands
vim.api.nvim_create_user_command("Q", "q", {})
vim.api.nvim_create_user_command("W", "w", {})

-- Close current buffer but leave window open
vim.api.nvim_create_user_command("BD", "bp|sp|bn|bd", {})

-- Format on save implementation
require("format")

-- Jupyter notebook keybinds
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("JupyterKeybinds", {clear = true}),
    pattern = "python",
    callback = function()
        -- TODO: Set different keybinds
        vim.keymap.set('n', '<F5>', ":JupyterSendCell<CR>", {buffer = 0})
        vim.keymap.set('n', '<F6>', ":JupyterRunFile<CR>", {buffer = 0})
        vim.keymap.set('n', '<F8>', ":PythonSetBreak<CR>", {buffer = 0})
        vim.keymap.set('n', '<F9>', ":JupyterRunFile %:p --verbose --plot <CR>", {buffer = 0})
        vim.keymap.set('n', '<F10>', ":JupyterCd %:p:h<CR>", {buffer = 0})
        vim.keymap.set('n', '<F11>', ":JupyterConnect<CR>", {buffer = 0})
    end
})

-- REST nvim keybinds
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("NvimRestKeybinds", {clear = true}),
    pattern = "http",
    callback = function()
        vim.keymap.set('n', '<F5>', ":Rest run<CR>", {buffer = 0})
        vim.keymap.set('n', '<F6>', ":Rest last<CR>", {buffer = 0})
        vim.keymap.set('n', '<F7>', ":Rest cookies<CR>", {buffer = 0})
        vim.keymap.set('n', '<F8>', ":Rest env select<CR>", {buffer = 0})
        vim.keymap.set('n', '<F9>', ":Rest env show<CR>", {buffer = 0})

        -- TODO This should be done in BufRead, BufOpen or similar events, if the file type is correct
        -- Define custom keybinds based on the file contents
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
        for _, line in ipairs(lines) do
            local key, name = line:match("^# BIND (%S+) (.+)$")
            if key and name then
                vim.keymap.set('n', key, ":Rest run " .. name .. "<CR>", {buffer = 0})
            end
        end
    end
})

-- Set the json formatter for REST nvim (https://github.com/rest-nvim/rest.nvim/issues/417)
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("JsonFormatForRestNvim", {clear = true}),
    pattern = {"json"},
    callback = function()
        vim.api.nvim_set_option_value("formatprg", "jq", {scope = 'local'})
    end
})

-- Plugins
require("plugins")
require("lsp")
