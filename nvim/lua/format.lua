
local debug = false

local prev_warned_missing = {}
local function run_formatter(path, ext, args)
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
        local key = ext .. args[1]
        if not prev_warned_missing[key] then
            print("Formatter", args[1], "not installed")
            print(" ")
            prev_warned_missing[key] = true
        end
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

local function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then
       io.close(f)
       return true
   else
       return false
   end
end

local function slice(tbl, start, len)
    local res = {}
    for i = start,start+len-1 do
        table.insert(res, tbl[i])
    end
    return res
end

local function create_edit(new_text, l_start, l_end, c_start, c_end)
    -- Reduce by one to comply with the LSP spec for text diffs (zero indexed):
    -- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#range
    local line_start = l_start - 1
    local line_end = l_end - 1
    local char_start = c_start
    local char_end = c_end
    return {
        newText = new_text,
        range = {
            start = {
                line = line_start,
                character = char_start,
            },
            ["end"] = {
            line = line_end,
            character = char_end,
        },
    },
}
end

local function default_formatters(ext)
    if string.find("*.py", ext) then
        return {"black", "--quiet", "%"}
    elseif string.find("*.h,*.cc,*.cpp,*.c,*.cu,*.hpp,*.vs,*.fs,*.vert,*.frag", ext) then
        if file_exists(".clang-format") then
            return {"clang-format", "-style=file:.clang-format", "-i", "%"}
        else
            return {"clang-format", "-i", "%"}
        end
    elseif string.find("*.js,*.ts,*.json,*.jsonc", ext) then
        return {"biome", "format", "%"}
    elseif string.find("*.rs", ext) then
        return {"cargo", "fmt", "--", "%"}
    elseif string.find("*.sh", ext) then
        -- return {"shfmt", "--indent", "4", "--space-redirects", "--case-indent", "--binary-next-line", "--language-dialect", "bash", "--write"}
        return {"shfmt", "-i", "4", "-sr", "-ci", "-bn", "-ln", "bash", "-w", "%"} -- Required for old version of shfmt...
    elseif string.find("*.xml", ext) then
        return {"python3", vim.fn.stdpath("config") .. "/format_xml.py", "--input", "%", "--output", "%"}
    end
end

local function office_formatters(ext)
    if string.find("*.js,*.ts,*.json,*.jsonc", ext) then
        return {"yarn", ":format", "%"}
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
    local orig_lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, true)
    local file_name = os.tmpname() .. "." .. name
    local file, err = io.open(file_name, "w+")
    if file then
        for idx = 1,#orig_lines do
            local success, err = file:write(orig_lines[idx] .. "\n") -- NOTE: This assumes \n and not \r\n
            if not success then
                print("Failed to write to file " .. file_name .. ", reason: " .. err)
                print(" ") -- Extra line in case output is swallowed by prompt
            end
        end
        file:close()
    else
        print("Failed to open file for writing " .. file_name .. ", reason: " .. err)
        print(" ") -- Extra line in case output is swallowed by prompt
        return
    end

    -- Run formatter on the temporary file
    local formatter_generators = {office_formatters, default_formatters}
    local formatter = {}
    for _, gen in ipairs(formatter_generators) do
        formatter = gen(ext)
        if formatter then
            break
        end
    end

    run_formatter(file_name, ext, formatter)

    -- Read formatted file
    local new_lines = {}
    file, err = io.open(file_name, "r")
    if file then
        for line in file:lines() do
            table.insert(new_lines, line)
        end
        -- vim.api.nvim_buf_set_lines(buffer, 0, -1, true, new_lines)
        file:close()
    else
        print("Failed to open file for reading " .. file_name .. ", reason: " .. err)
        print(" ") -- Extra line in case output is swallowed by prompt
        return
    end

    local success, err = os.remove(file_name)
    if not success then
        print("Failed to delete temp file " .. file_name .. ", reason: " .. err)
        print(" ") -- Extra line in case output is swallowed by prompt
        return
    end

    -- Find diffs and apply
    local orig_text = table.concat(orig_lines, "\n")
    local new_text = table.concat(new_lines, "\n")
    local indices = vim.diff(orig_text, new_text, {result_type = 'indices', algorithm = 'histogram'})
    if debug then
        local function ptbl(tbl)
            local str = ""
            for idx = 1,#tbl do
                local tmp = tbl[idx]
                if type(tmp) == "table" then
                    ptbl(tmp)
                else
                    str = str .. tmp .. " "
                end
            end
            print(str)
        end

        ptbl(indices)
        print(" ")
    end

    local edits = {}
    for _, idx in ipairs(indices) do
        local o_start, o_len, n_start, n_len = unpack(idx)
        local new_text = table.concat(slice(new_lines, n_start, n_len), "\n")
        if o_len == 0 then
            -- Insertion
            if o_start < #orig_lines then
                new_text = new_text .. "\n"
            end
            table.insert(edits, create_edit(new_text, o_start + 1, o_start + 1, 0, 0))
        elseif n_len == 0 then
            -- Deletion
            table.insert(edits, create_edit("", o_start, o_start + o_len - 1 + 1, 0, 0))
        else
            -- Replacement, could be improved by diffing within the lines too
            table.insert(edits, create_edit(new_text, o_start, o_start + o_len - 1, 0, orig_lines[o_start + o_len - 1]:len()))
        end
    end
    if debug then
        for _, edit in ipairs(edits) do
            print("Edit:")
            print("- " .. edit.newText)
            print("- start: " .. edit.range.start.line .. ", "  .. edit.range.start.character)
            print("- end: " .. edit.range["end"].line .. ", "  .. edit.range["end"].character)
        end
        print(" ")
    end

    vim.lsp.util.apply_text_edits(edits, buffer, "utf-8")
end, { nargs='?'})

-- TODO We also want to support files with shebangs and no extension, e.g. detect
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
