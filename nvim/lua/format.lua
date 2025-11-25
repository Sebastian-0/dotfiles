local debug = false

local prev_warned_missing = {}
local function run_formatter(filetype, args, stdin, print_stdout_on_error)
    if debug then
        print(vim.inspect(args))
    end
    local ok, res = pcall(vim.system, args, {stdin = stdin, text = true})
    if not ok then
        local key = filetype .. args[1]
        if not prev_warned_missing[key] then
            print("Formatter", args[1], "not installed")
            print(" ")
            prev_warned_missing[key] = true
        end
        return
    end
    res = res:wait()
    if res.code ~= 0 and filetype ~= "zig" then -- TODO: Temp fix here because zig returns empty stdout/stderr always, and errors even on success...
        print("Formatting failed!")
        if print_stdout_on_error then
            print(res.stdout)
        end
        print(res.stderr)
        print("-> Return code:", res.code)
        print(" ")
        return
    end
    return res.stdout
end

local function file_exists(name)
    local f = io.open(name, "r")
    if f ~= nil then
        io.close(f)
        return true
    else
        return false
    end
end

local function slice(tbl, start, len)
    local res = {}
    for i = start, start + len - 1 do
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
        range = {start = {line = line_start, character = char_start}, ["end"] = {line = line_end, character = char_end}}
    }
end

local function default_formatters(filetype)
    if string.find("python", filetype) then
        return true, {"black", "--quiet", "-"}
    elseif string.find("cuda,cpp,c,glsl", filetype) then
        if file_exists(".clang-format") then
            return true, {"clang-format", "--style=file:.clang-format"}
        else
            return true, {"clang-format", "--style={IndentWidth: 4}"}
        end
    elseif string.find("javascript,typescript,json,jsonc", filetype) then
        return true, {"biome", "format", "-"}
    elseif string.find("rust", filetype) then
        return true, {"rustfmt"}
    elseif string.find("sh", filetype) then
        -- return true, {"shfmt", "--indent", "4", "--space-redirects", "--case-indent", "--binary-next-line", "--language-dialect", "bash"}
        return true, {"shfmt", "-i", "4", "-sr", "-ci", "-bn", "-ln", "bash"} -- Required for old version of shfmt...
    elseif string.find("lua", filetype) then
        return true, {
            "lua-format",
            "--chop-down-table",
            "--chop-down-kv-table",
            "--no-keep-simple-function-one-line",
            "--no-keep-simple-control-block-one-line",
            "--column-limit=120"
        }
    elseif string.find("xml", filetype) then
        return false, {"python3", vim.fn.stdpath("config") .. "/format_xml.py", "--input", "%", "--output", "%"}
    elseif string.find("zig", filetype) then
        -- return true, {"zig", "fmt", "--stdin"}
        -- return true, {"zig", "fmt", "--stdin", "--color", "off"}
        -- return true, {"bash", "-c", "zig fmt --stdin --color off"}
        return false, {"zig", "fmt", "%"}
        -- return {"cat", "%", "|", "zig", "fmt", "--stdin", ">", "%"}
    end
end

local function office_formatters(filetype)
    if os.getenv("NVIM_ENV") ~= "intuicell" then
        return
    end

    if string.find("javascript,typescript,json,jsonc", filetype) then
        return false, {"yarn", ":biome", "format", "--no-errors-on-unmatched", "--write", "%"}
    end
end

local function format_with_temp_file(orig_lines, buffer, formatter)
    local buf = vim.api.nvim_buf_get_name(buffer)
    local name = buf:match("/([^/]+)$")

    -- Create a temporary file and write buffer contents
    local file_name = os.tmpname() .. "." .. name
    local file, err = io.open(file_name, "w+")
    if file then
        for idx = 1, #orig_lines do
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
    for i = 1, #formatter do
        if formatter[i] == "%" then
            formatter[i] = file_name
        end
    end
    local res = run_formatter(vim.bo[buffer].filetype, formatter, true)
    if not res then
        return
    end

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

    return new_lines
end

local function format_with_stdin(orig_lines, buffer, file_name, formatter)
    for i = 1, #formatter do
        if formatter[i] == "%" then
            formatter[i] = file_name
        end
    end
    local res = run_formatter(vim.bo[buffer].filetype, formatter, orig_lines, false)
    if res then
        return vim.split(res, "\n")
    end
end

vim.api.nvim_create_user_command('RunFormatter', function(opts)
    local buffer = 0
    if opts.args then
        local res = tonumber(opts.args)
        if res then
            buffer = res
        end
    end

    -- Select a formatter
    local formatter_generators = {office_formatters, default_formatters}
    local formatter = {}
    local use_stdin = false
    for _, gen in ipairs(formatter_generators) do
        use_stdin, formatter = gen(vim.bo[buffer].filetype)
        if formatter then
            break
        end
    end

    if not formatter then
        return
    end

    local orig_lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, true)
    local new_lines = {}
    if use_stdin then
        new_lines = format_with_stdin(orig_lines, buffer, vim.api.nvim_buf_get_name(buffer), formatter)
    else
        new_lines = format_with_temp_file(orig_lines, buffer, formatter)
    end

    if not new_lines then
        return
    end

    -- Find diffs and apply
    local orig_text = table.concat(orig_lines, "\n")
    local new_text = table.concat(new_lines, "\n")
    local indices = vim.diff(orig_text, new_text, {result_type = 'indices', algorithm = 'histogram'})
    if debug then
        local function ptbl(tbl)
            local str = ""
            for idx = 1, #tbl do
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
            table.insert(edits,
                         create_edit(new_text, o_start, o_start + o_len - 1, 0, orig_lines[o_start + o_len - 1]:len()))
        end
    end
    if debug then
        for _, edit in ipairs(edits) do
            print("Edit:")
            print("- " .. edit.newText)
            print("- start: " .. edit.range.start.line .. ", " .. edit.range.start.character)
            print("- end: " .. edit.range["end"].line .. ", " .. edit.range["end"].character)
        end
        print(" ")
    end

    vim.lsp.util.apply_text_edits(edits, buffer, "utf-8")
end, {nargs = '?'})

vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = "*",
    group = vim.api.nvim_create_augroup("AutoFormat", {clear = true}),
    callback = function(args)
        vim.cmd({cmd = "RunFormatter", args = {tostring(args.buf)}})
    end
})
