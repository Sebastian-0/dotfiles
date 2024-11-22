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

-- Set filetype for glsl
vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
    group = vim.api.nvim_create_augroup("GlslLangType", { clear = true }),
    pattern = { "*.frag", "*.vert", "*.fs", "*.vs" },
    command = [[set filetype=glsl]]
})

-- Set comment character for certain file types
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("CommentString", { clear = true }),
    pattern = { "c", "cpp", "cuda", "glsl" },
    command = [[setlocal commentstring=//\ %s]]
})

-- Add column showing maximum width for commit bodies
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("GitCommitBodyMarker", { clear = true }),
    pattern = "gitcommit",
    callback = function ()
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
local function run_formatter(path, args)
    for i = 1,#args do
        if args[i] == "%" then
            args[i] = path
        end
    end
    local function wrap()
        return vim.system(args):wait()
    end
    local ok, res = pcall(wrap)
    if not ok then
        print("Formatter", args[1], "not installed")
        print(" ")
    else
        if res.code ~= 0 then
            print("Formatting failed!")
            print(res.stdout)
            print(res.stderr)
            print("-> Return code:", res.code)
            print(" ")
        end
    end
end

function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then
       io.close(f)
       return true
   else
       return false
   end
end

vim.api.nvim_create_user_command('RunFormatter', function(opts)
    local buffer = 0
    local ext = nil
    if opts.args then
        local res = tonumber(opts.args)
        if res then
            buffer = res
        else
            ext = opts.args
        end
    end
    local buf = vim.api.nvim_buf_get_name(buffer)
    local name = buf:match("/([^/]+)$")
    if ext == nil then
        ext = buf:match("%.([^%.]+)$")
    end

    if ext == nil or ext == '' then
        return
    end

    -- Create a temporary file and write buffer contents
    local file_name = os.tmpname() .. "." .. name
    local file, err = io.open(file_name, "w+")
    if file then
        local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, true)
        for idx = 1,#lines do
            local success, err = file:write(lines[idx] .. "\n") -- NOTE: This assumes \n and not \r\n
            if not success then
                print("Failed to write to file " .. file_name .. ", reason: " .. err)
                print(" ") -- Extra line in case output is swallowed by prompt
            end
        end
        file:close()
    else
        print("Failed to open file for writing " .. file_name .. ", reason: " .. err)
        print(" ") -- Extra line in case output is swallowed by prompt
    end

    -- Run formatter on the temporary file
    if string.find("*.py", ext) then
        run_formatter(file_name, {"black", "--quiet", "%"})
    elseif string.find("*.h,*.cc,*.cpp,*.c,*.cu,*.hpp,*.vs,*.fs,*.vert,*.frag", ext) then
        if file_exists(".clang-format") then
            run_formatter(file_name, {"clang-format", "-style=file:.clang-format", "-i", "%"})
        else
            run_formatter(file_name, {"clang-format", "-i", "%"})
        end
    elseif string.find("*.js,*.ts,*.json,*.jsonc", ext) then
        run_formatter(file_name, {"yarn", ":format", "%"})
    elseif string.find("*.rs", ext) then
        run_formatter(file_name, {"cargo", "fmt", "--", "%"})
    elseif string.find("*.sh", ext) then
        -- run_formatter(file_name, {"shfmt", "--indent", "4", "--space-redirects", "--case-indent", "--binary-next-line", "--language-dialect", "bash", "--write"})
        run_formatter(file_name, {"shfmt", "-i", "4", "-sr", "-ci", "-bn", "-ln", "bash", "-w", "%"}) -- Required for old version of shfmt...
    elseif string.find("*.xml", ext) then
        run_formatter(file_name, {"python3", vim.fn.stdpath("config") .. "/format_xml.py", "--input", "%", "--output", "%"})
    end

    -- Copy temporary file back into buffer
    file, err = io.open(file_name, "r")
    if file then
        local lines = {}
        for line in file:lines() do
            table.insert(lines, line)
        end
        vim.api.nvim_buf_set_lines(buffer, 0, -1, true, lines)
        file:close()
    else
        print("Failed to open file for reading " .. file_name .. ", reason: " .. err)
        print(" ") -- Extra line in case output is swallowed by prompt
    end

    local success, err = os.remove(file_name)
    if not success then
        print("Failed to delete temp file " .. file_name .. ", reason: " .. err)
        print(" ") -- Extra line in case output is swallowed by prompt
    end
end, { nargs='?'})

-- TODO The proper way to implement format on save is to use BufWritePre and
--      edit the buffer in place. Then we need to access the buffer in a general
--      way that works for all formatters. Maybe take inspiration from:
--      /usr/share/clang/clang-format-14/clang-format.py
--      Probably we need to write the buffer to another file, then format, and
--      then read the file and overwrite the vim buffer.
--
--      We also want to support files with shebangs and no extension, e.g. detect
--      /.../sh and /.../python and map to an appropriate language
vim.api.nvim_create_autocmd(
    "BufWritePre",
    {
        pattern = "*",
        group = vim.api.nvim_create_augroup("AutoFormat", { clear = true }),
        callback = function(args)
            vim.cmd( {cmd = "RunFormatter", args = {tostring(args.buf)}})
        end,
    }
)

-- TODO: Set different keybinds
vim.keymap.set('n', '<F6>',  ":JupyterRunFile<CR>")
vim.keymap.set('n', '<F5>',  ":JupyterSendCell<CR>")
vim.keymap.set('n', '<F8>',  ":PythonSetBreak<CR>")
vim.keymap.set('n', '<F9>',  ":JupyterRunFile %:p --verbose --plot <CR>")
vim.keymap.set('n', '<F10>', ":JupyterCd %:p:h<CR>")
vim.keymap.set('n', '<F11>', ":JupyterConnect<CR>")

-- Plugins
require("plugins")
