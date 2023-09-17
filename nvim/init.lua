vim.opt.relativenumber = true
vim.opt.number = true
vim.opt.mouse = "v" -- Enabled for visual mode
--vim.opt.cursorline = true
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

vim.g.mapleader = " "
vim.keymap.set("n", " ", "")

vim.g.netrw_liststyle = 3
vim.g.netrw_altv = 1
vim.g.netrw_winsize = 75
vim.g.netrw_list_hide = "\\(^\\|\\s\\s\\)\\zs\\.\\S\\+" -- Hide all dotfiles by default
--vim.g.netrw_browsex_viewer = "xdg-open" -- Controls what happens when pressing x over files, for some reason not working...

-- Return to last position
local returnGroup = vim.api.nvim_create_augroup("ReturnToLast", { clear = true })
vim.api.nvim_create_autocmd("BufReadPost", {
    group = returnGroup,
    command = [[if line("'\"") > 1 && line("'\"") <= line("$") | execute "normal! g'\"" | endif]]
})

-- Moving lines of code
vim.keymap.set("n", "<a-j>", ":m .+1<CR>==")
vim.keymap.set("n", "<a-k>", ":m .-2<CR>==")
vim.keymap.set("i", "<a-j>", "<Esc>:m .+1<CR>==gi")
vim.keymap.set("i", "<a-k>", "<Esc>:m .-2<CR>==gi")
vim.keymap.set("v", "<a-j>", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "<a-k>", ":m '<-2<CR>gv=gv")

-- Make Y copy rest of line
vim.keymap.set("n", "Y", "y$")

-- Plugins
-- require("plugins")
