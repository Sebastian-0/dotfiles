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
--vim.opt.signcolumn = "yes" -- Could also set this to "number"
--vim.opt.completeopt = "menu" -- I don't notice the difference...

-- Increase performance of searches (https://github.com/neovim/neovim/issues/23590#issuecomment-1911925029)
vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("SearchSpeedup", { clear = true }),
    command = [[hi! link CurSearch Search]]
})

-- Leader
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

-- Format on save implementation
local function run_formatter(args)
    table.insert(args, vim.fn.expand('%'))
    local function wrap()
        return vim.system(args):wait()
    end
    local ok, res = pcall(wrap)
    if not ok then
        print("Formatter", args[1], "not installed")
    else
        if res.code ~= 0 then
            print("Formatting failed!")
            print(res.stdout)
            print(res.stderr)
            print("-> Return code:", res.code)
        end
    end
end

vim.api.nvim_create_user_command('RunFormatter', function(opts)
    local ext = vim.fn.expand("%:e")
    if ext == nil or ext == '' then
        return
    end
    if string.find("*.py", ext) then
        run_formatter({"black", "--quiet"})
        vim.cmd("edit")
    elseif string.find("*.h,*.cc,*.cpp,*.c,*.cu,*.ino,*.vert,*.frag", ext) then
        run_formatter({"clang-format", "-i"})
        vim.cmd("edit")
    elseif string.find("*.js,*.ts", ext) then
        run_formatter({"yarn", ":format"})
        vim.cmd("edit")
    end
end, {})

-- TODO The proper way to implement format on save is to use BufWritePre and
--      edit the buffer in place. Then we need to access the buffer in a general
--      way that works for all formatters. Maybe take inspiration from:
--      /usr/share/clang/clang-format-14/clang-format.py
--      Probably we need to write the buffer to another file, then format, and
--      then read the file and overwrite the vim buffer.
vim.api.nvim_create_autocmd(
    "BufWritePost",
    {
        pattern = "*",
        group = vim.api.nvim_create_augroup("AutoFormat", { clear = true }),
        callback = function()
            vim.cmd("RunFormatter")
        end,
    }
)

-- Plugins
require("plugins")
