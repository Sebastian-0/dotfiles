vim.opt.relativenumber = true
vim.opt.number = true
vim.opt.mouse = ""
vim.opt.cursorline = true
-- vim.opt.cursorcolumn = true -- Produces very laggy scrolling
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

-- This is only needed for norcalli/nvim-colorizer.lua to work
vim.opt.termguicolors = true

-- Increase performance of searches (https://github.com/neovim/neovim/issues/23590#issuecomment-1911925029)
vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("SearchSpeedup", {clear = true}),
    command = [[hi! link CurSearch Search]]
})

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
vim.keymap.set("n", "j", "gj")
vim.keymap.set("n", "k", "gk")

-- Extra save and quit commands
vim.api.nvim_create_user_command("Q", "q", {})
vim.api.nvim_create_user_command("W", "w", {})

-- Close current buffer but leave window open
vim.api.nvim_create_user_command("BD", "bp|sp|bn|bd", {})

-- Format on save implementation
require("format")

-- TODO: Set different keybinds
vim.keymap.set('n', '<F6>', ":JupyterRunFile<CR>")
vim.keymap.set('n', '<F5>', ":JupyterSendCell<CR>")
vim.keymap.set('n', '<F8>', ":PythonSetBreak<CR>")
vim.keymap.set('n', '<F9>', ":JupyterRunFile %:p --verbose --plot <CR>")
vim.keymap.set('n', '<F10>', ":JupyterCd %:p:h<CR>")
vim.keymap.set('n', '<F11>', ":JupyterConnect<CR>")

-- Plugins
require("plugins")
