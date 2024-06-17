vim.opt.relativenumber = true
vim.opt.number = true
vim.opt.mouse = "a"
vim.opt.cursorline = true
vim.opt.cursorcolumn = true
vim.opt.scrolloff = 5
vim.opt.tabstop = 4
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.breakindent = true
vim.opt.breakindentopt = "shift:2"
vim.opt.wildmode = "longest,list"
vim.opt.ignorecase = true
--vim.opt.signcolumn = "yes" -- Could also set this to "number"
--vim.opt.completeopt = "menu" -- I don't notice the difference...

-- Block mouse clicks, need to do it like this to conserve scroll behaviour of mouse=a
vim.keymap.set({"n", "i", "v"}, "<LeftMouse>", "<nop>")
vim.keymap.set({"n", "i", "v"}, "<2-LeftMouse>", "<nop>")
vim.keymap.set({"n", "i", "v"}, "<RightMouse>", "<nop>")
vim.keymap.set({"n", "i", "v"}, "<2-RightMouse>", "<nop>")

vim.g.mapleader = " "
vim.keymap.set("n", " ", "")

vim.g.netrw_liststyle = 3
vim.g.netrw_altv = 1
vim.g.netrw_winsize = 75
vim.g.netrw_list_hide = "\\(^\\|\\s\\s\\)\\zs\\.\\S\\+" -- Hide all dotfiles by default
--vim.g.netrw_browsex_viewer = "xdg-open" -- Controls what happens when pressing x over files, for some reason not working...
vim.g.netrw_bufsettings = "noma nomod nobl nowrap ro number relativenumber"

-- Return to previous position when opening a file
vim.api.nvim_create_autocmd("BufReadPost", {
    group = vim.api.nvim_create_augroup("ReturnToLast", { clear = true }),
    command = [[if line("'\"") > 1 && line("'\"") <= line("$") | execute "normal! g'\"" | endif]]
})

-- Stop automatic comments
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("NoAutoComment", { clear = true }),
    callback = function()
        vim.opt.formatoptions:remove({ "o", "r" })
    end
})

-- Set comment character for certain file types
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("CommentString", { clear = true }),
    pattern = { "c", "cpp", "cuda" },
    command = [[setlocal commentstring=//\ %s]]
})

-- Moving lines of code
vim.keymap.set("n", "<a-j>", ":m .+1<CR>==")
vim.keymap.set("n", "<a-k>", ":m .-2<CR>==")
vim.keymap.set("i", "<a-j>", "<Esc>:m .+1<CR>==gi")
vim.keymap.set("i", "<a-k>", "<Esc>:m .-2<CR>==gi")
vim.keymap.set("v", "<a-j>", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "<a-k>", ":m '<-2<CR>gv=gv")

-- Center view when jumping
-- vim.keymap.set("n", "<C-d>", "<C-d>zz")  -- These doesn't work with neoscroll enabled...
-- vim.keymap.set("n", "<c-u>", "<C-u>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- Make Y copy rest of line
vim.keymap.set("n", "Y", "y$")

-- Extra save and quit commands
vim.api.nvim_create_user_command("Q", "q", {})
vim.api.nvim_create_user_command("W", "w", {})

-- Close current buffer but leave window open
vim.api.nvim_create_user_command("BD", "bp|sp|bn|bd", {})

-- Plugins
require("plugins")
