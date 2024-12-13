
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
