-- Refactor: Advanced Find & Replace Plugin Module for NeoVim
-- Version: 0.1.1
-- Author: Md. Shifat Hasan (ShifatHasanGNS)
-- License: MIT

local M = {}

local config = {
    default_flags = "",
    -- Case-insensitive, Partial-match, Literal-text, Normal-case
}

local refactor_state = {
    cancelled = false
}

local function smart_notify(message, level, max_width)
    max_width = max_width or 80
    level = level or vim.log.levels.INFO
    
    if type(message) ~= "string" then
        message = tostring(message)
    end
    
    -- Split Long Messages
    if #message > max_width then
        local lines = {}
        local current_line = ""
        
        for word in message:gmatch("%S+") do
            if #current_line + #word + 1 <= max_width then
                current_line = current_line == "" and word or current_line .. " " .. word
            else
                if current_line ~= "" then
                    table.insert(lines, current_line)
                end
                current_line = word
            end
        end
        
        if current_line ~= "" then
            table.insert(lines, current_line)
        end
        
        -- Notify Each Line With Delay
        for i, line in ipairs(lines) do
            vim.defer_fn(function()
                vim.notify(line, level)
            end, (i - 1) * 100)  -- 100ms delay between notifications
        end
    else
        vim.notify(message, level)
    end
end

-- Parse Flags: Flexible Order
local function parse_flags(flag_str)
    flag_str = flag_str or ""
    flag_str = vim.trim(flag_str):lower()

    local valid_chars = { 'c', 'w', 'r', 'p' }
    local seen_chars = {}

    for i = 1, #flag_str do
        local char = flag_str:sub(i, i)
        if not vim.tbl_contains(valid_chars, char) then
            smart_notify(string.format("❌ Invalid flag '%s'. Valid: c,w,r,p", char), vim.log.levels.ERROR)
            return nil
        end
        if seen_chars[char] then
            smart_notify(string.format("❌ Duplicate flag '%s'", char), vim.log.levels.ERROR)
            return nil
        end
        seen_chars[char] = true
    end

    -- Default: Case-insensitive, Partial-match, Literal-text, Normal-case
    local flags = {
        case_sensitive = flag_str:find('c') ~= nil,
        whole_word = flag_str:find('w') ~= nil,
        use_regex = flag_str:find('r') ~= nil,
        preserve_case = flag_str:find('p') ~= nil
    }

    if flag_str == "" then
        flags = {
            case_sensitive = false,
            whole_word = false,
            use_regex = false,
            preserve_case = false
        }
    end

    return flags
end

-- Build Pattern: Escape & Validate
local function build_search_pattern(find_str, flags)
    local pattern = find_str

    pattern = pattern:gsub('[\n\r]', '')

    if pattern == "" then
        smart_notify("⚠️ Empty search pattern", vim.log.levels.WARN)
        return nil
    end

    if not flags.use_regex then
        pattern = pattern:gsub('([/\\])', '\\%1')
    else
        local ok, _ = pcall(vim.fn.match, "test", pattern)
        if not ok then
            smart_notify("❌ Invalid regex pattern", vim.log.levels.ERROR)
            return nil
        end
    end

    if flags.whole_word then
        pattern = '\\<' .. pattern .. '\\>'
    end

    if flags.use_regex then
        pattern = '\v' .. pattern
    end

    return pattern
end

local function escape_replacement_string(replace_str, preserve_case)
    local single_line = replace_str:gsub('[\n\r]', '')
    if preserve_case then
        return '\\=luaeval("_G.refactor_preserve_case_replace(submatch(0), \'' ..
               vim.fn.escape(single_line, "'\\") .. '\')"'
    else
        local escaped = single_line:gsub('([/\\])', '\\%1')
        return escaped
    end
end

local function apply_case_preservation(original, replacement)
    if original == "" or replacement == "" then
        return replacement
    end

    if original == original:upper() and original ~= original:lower() then
        return replacement:upper()
    end

    if original == original:lower() and original ~= original:upper() then
        return replacement:lower()
    end

    if original:sub(1, 1) == original:sub(1, 1):upper() and
        (#original == 1 or original:sub(2) == original:sub(2):lower()) then
        return replacement:sub(1, 1):upper() .. replacement:sub(2):lower()
    end

    local upper_ratio = 0
    for i = 1, #original do
        if original:sub(i, i):match("%u") then
            upper_ratio = upper_ratio + 1
        end
    end
    upper_ratio = upper_ratio / #original

    if upper_ratio > 0.5 then
        return replacement:upper()
    else
        return replacement:lower()
    end
end

-- Global Wrapper-Function for 'apply_case_preservation' Function
function _G.refactor_preserve_case_replace(original, replacement)
    return apply_case_preservation(original, replacement)
end

-- Get Input: ESC Cancels, with mode for input type (required)
-- mode: "flag", "find", "replace" (must be specified)
local function get_input_with_esc(prompt, default, mode)
    assert(mode == "flag" or mode == "find" or mode == "replace" or mode == "confirm", "Invalid mode")
    default = default or ""

    vim.cmd('call inputsave()')
    local result = vim.fn.input(prompt, default)
    vim.cmd('call inputrestore()')

    if result == nil then
        -- This case shouldn’t normally happen with vim.fn.input, but we’ll handle it
        refactor_state.cancelled = true
        smart_notify("🚫 Operation Cancelled", vim.log.levels.INFO)
        return nil
    end

    if mode == "find" and result == '' then
        -- Cancel if no find string is provided
        smart_notify("🚫 No Find String was Entered", vim.log.levels.INFO)
        refactor_state.cancelled = true
        return nil
    end

    return result
end

local function check_cancelled()
    if refactor_state.cancelled then
        return true
    end
    return false
end

-- Buffer Replace with Smart Delimiter
local function execute_buffer_replace(params)
    if check_cancelled() then return false end
    
    local pattern = build_search_pattern(params.find, params.flags)  
    if not pattern then return false end
    
    local replace = escape_replacement_string(params.replace, params.flags.preserve_case)
    
    -- Pick Safe Delimiter
    local delim_options = {'/', '#', '@', '|', '!', '%', '~', ';', ':'}
    local delimiter = nil
    for _, delim in ipairs(delim_options) do
        if not pattern:find(vim.pesc(delim)) and not replace:find(vim.pesc(delim)) then
            delimiter = delim
            break
        end
    end
    if not delimiter then
        smart_notify("❌ Could not find a safe delimiter for substitution", vim.log.levels.ERROR)
        return false
    end
    -- Escape For Delimiter
    if delimiter ~= '/' then
        pattern = pattern:gsub('\\/', '/')
        pattern = vim.fn.escape(pattern, delimiter)
        if not params.flags.preserve_case then
            replace = replace:gsub('\\/', '/')
            replace = vim.fn.escape(replace, delimiter)
        end
    end
    local cmd = '%s' .. delimiter .. pattern .. delimiter .. replace .. delimiter .. 'gc'
    if not params.flags.case_sensitive then
        cmd = cmd .. 'i'
    end
    smart_notify("🔍 Searching in: " .. vim.fn.expand('%:t'), vim.log.levels.INFO)
    local ok, result = pcall(function() vim.cmd(cmd) end)
    if not ok then
        smart_notify("❌ Replace failed. Try different flags or check special characters", vim.log.levels.ERROR)
        return false
    else
        smart_notify("✅ Buffer replace completed", vim.log.levels.INFO)
        return true
    end
end

-- Async Input
local function get_user_input(scope)
    refactor_state.cancelled = false  -- Reset Cancel
    
    vim.cmd('redraw')
    
    -- Show Help Info
    smart_notify("🔧 Refactor: " .. (scope == "quickfix" and "Quickfix List" or "Current Buffer"), vim.log.levels.INFO)
    smart_notify("Press ESC at any input to cancel", vim.log.levels.INFO)
    
    vim.defer_fn(function()
        smart_notify("Flag Format: [c w r p] (any order, optional)", vim.log.levels.INFO)
    end, 200)
    
    vim.defer_fn(function()
        smart_notify("Flags: c=Case-sensitive, w=Whole-word, r=RegEx, p=Preserve-case", vim.log.levels.INFO)
    end, 400)
    
    vim.defer_fn(function()
        smart_notify("Examples: 'cw'=Case+Whole, 'p'=Preserve only, ''=All defaults", vim.log.levels.INFO)
    end, 600)
    
    -- Wait For Notifications
    vim.defer_fn(function()
        -- Get flags (empty input means use default flags)
        local flags_input = get_input_with_esc("Flags [c w r p]: ", config.default_flags, "flag")
        if flags_input == nil then return end  -- Cancelled
        local flags = parse_flags(flags_input or "")
        if check_cancelled() or not flags then return end

        local flag_display = {}
        table.insert(flag_display, flags.case_sensitive and "Case-sensitive" or "Case-insensitive")
        table.insert(flag_display, flags.whole_word and "Whole-word" or "Partial-match")
        table.insert(flag_display, flags.use_regex and "RegEx" or "Literal-text")
        table.insert(flag_display, flags.preserve_case and "Preserve-case" or "Normal-case")
        smart_notify("Active: " .. table.concat(flag_display, " | "), vim.log.levels.INFO)

        -- Get find string (required)
        local find_str = get_input_with_esc("Find: ", "", "find")
        if find_str == nil then return end  -- Cancelled due to empty input

        -- Get replace string (empty is allowed)
        local replace_str = get_input_with_esc("Replace: ", "", "replace")
        if replace_str == nil then return end  -- Cancelled

        -- Confirmation step
        local confirm = get_input_with_esc("Proceed with these settings? [Y/n]: ", "Y", "confirm")
        if confirm == nil or confirm:lower() == "n" then
            smart_notify("🚫 Operation Cancelled", vim.log.levels.INFO)
            return
        end

        -- Prepare parameters and proceed
        local params = {
            flags = flags,
            find = find_str,
            replace = replace_str or ""  -- Ensure it’s a string
        }
        vim.defer_fn(function()
            if not check_cancelled() then
                M._continue_refactor(scope, params)
            end
        end, 100)
    end, 800)

    return nil  -- Asynchronous operation
end

local function execute_quickfix_replace(params)
    if check_cancelled() then return false end

    local qf_list = vim.fn.getqflist()
    local qf_count = #qf_list

    if qf_count == 0 then
        smart_notify("📋 No quickfix entries found", vim.log.levels.WARN)
        return false
    end

    local pattern = build_search_pattern(params.find, params.flags)
    if not pattern then return false end

    smart_notify(string.format("🔧 Processing %d quickfix entries...", qf_count), vim.log.levels.INFO)

    local total_replacements = 0

    local original_buf = vim.fn.bufnr('%')
    local original_pos = vim.fn.getcurpos()

    -- Pick Safe Delimiter
    local delim_options = {'/', '#', '@', '|', '!', '%', '~', ';', ':'}
    local delimiter = nil
    local replace = escape_replacement_string(params.replace, params.flags.preserve_case)
    for _, delim in ipairs(delim_options) do
        if not pattern:find(vim.pesc(delim)) and not replace:find(vim.pesc(delim)) then
            delimiter = delim
            break
        end
    end
    if not delimiter then
        smart_notify("❌ Could not find a safe delimiter for substitution", vim.log.levels.ERROR)
        return false
    end
    if delimiter ~= '/' then
        pattern = pattern:gsub('\\/', '/')
        pattern = vim.fn.escape(pattern, delimiter)
        if not params.flags.preserve_case then
            replace = replace:gsub('\\/', '/')
            replace = vim.fn.escape(replace, delimiter)
        end
    end

    -- Collect line numbers for each buffer
    local buffers_to_lines = {}
    for _, qf_item in ipairs(qf_list) do
        if qf_item.bufnr and qf_item.bufnr > 0 and qf_item.lnum and qf_item.lnum > 0 then
            if not buffers_to_lines[qf_item.bufnr] then
                buffers_to_lines[qf_item.bufnr] = {}
            end
            table.insert(buffers_to_lines[qf_item.bufnr], qf_item.lnum)
        end
    end

    for bufnr, line_numbers in pairs(buffers_to_lines) do
        if check_cancelled() then break end

        local filename = vim.fn.bufname(bufnr)
        local display_name = vim.fn.fnamemodify(filename, ":t")

        smart_notify(string.format("🔄 Processing: %s (%d locations)", display_name, #line_numbers), vim.log.levels.INFO)

        local ok = pcall(function()
            if not vim.fn.bufloaded(bufnr) then
                vim.cmd('badd ' .. vim.fn.fnameescape(filename))
            end
            vim.cmd('buffer ' .. bufnr)

            table.sort(line_numbers)
            local replacements_in_buf = 0
            for _, lnum in ipairs(line_numbers) do
                if check_cancelled() then break end
                local cmd = string.format('%ds%s%s%s%s%sgc', lnum, delimiter, pattern, delimiter, replace, delimiter)
                if not params.flags.case_sensitive then
                    cmd = cmd .. 'i'
                end
                -- Count replacements by capturing :substitute output
                local sub_output = vim.fn.execute(cmd)
                local n = tonumber(sub_output:match('(%d+) substitutions')) or 0
                replacements_in_buf = replacements_in_buf + n
            end
            vim.cmd('write')
            total_replacements = total_replacements + replacements_in_buf
        end)

        if not ok then
            smart_notify("❌ Failed: " .. display_name, vim.log.levels.ERROR)
        else
            smart_notify("✅ Success: " .. display_name, vim.log.levels.INFO)
        end
    end

    pcall(function()
        if vim.fn.bufexists(original_buf) then
            vim.cmd('buffer ' .. original_buf)
            vim.fn.setpos('.', original_pos)
        end
    end)

    if total_replacements > 0 then
        smart_notify("✅ Quickfix: " .. total_replacements .. " replacements made", vim.log.levels.INFO)
        vim.cmd('copen')
        return true
    else
        smart_notify("❌ Quickfix: No entries processed", vim.log.levels.ERROR)
        return false
    end
end

-- After Input
function M._continue_refactor(scope, params)
    if check_cancelled() then return end
    
    local flag_chars = {}
    if params.flags.case_sensitive then table.insert(flag_chars, "c") end
    if params.flags.whole_word then table.insert(flag_chars, "w") end
    if params.flags.use_regex then table.insert(flag_chars, "r") end
    if params.flags.preserve_case then table.insert(flag_chars, "p") end
    
    local flag_str = table.concat(flag_chars, "")
    if flag_str == "" then flag_str = "none" end

    smart_notify(string.format("🚀 Refactor [%s]: '%s' → '%s'", flag_str, params.find, params.replace), vim.log.levels.INFO)

    local success
    if scope == "quickfix" then
        success = execute_quickfix_replace(params)
    else
        success = execute_buffer_replace(params)
    end

    local function delayed_notify(msg, level)
        -- Estimate reading time: 3 words per second
        local word_count = 0
        for _ in tostring(msg):gmatch("%S+") do word_count = word_count + 1 end
        local delay_ms = math.max(2000, math.ceil(word_count / 3 * 1000))
        vim.defer_fn(function()
            smart_notify(msg, level)
        end, delay_ms)
    end

    if success then
        delayed_notify("🎉 Refactor completed successfully!", vim.log.levels.INFO)
    else
        delayed_notify("⚠️ Refactor encountered errors", vim.log.levels.WARN)
    end
end

-- Main Refactor
local function refactor(use_quickfix)
    local scope = use_quickfix and "quickfix" or "buffer"
    -- ESC is handled by input()
    get_user_input(scope)
end

function M.setup(opts)
    opts = opts or {}

    if opts.default_flags then
        config.default_flags = opts.default_flags
    end

    vim.api.nvim_create_user_command('RefactorB', function()
        refactor(false)
    end, { desc = "Advanced Find and Replace in Current Buffer" })

    vim.api.nvim_create_user_command('RefactorQ', function()
        refactor(true)
    end, { desc = "Advanced Find and Replace in QuickFix List" })

    local keymap_opts = { silent = true, noremap = true }
    local base_keymap = opts.keymap or '<leader>r'

    vim.keymap.set('n', base_keymap, function()
    end, vim.tbl_extend('force', keymap_opts, { desc = "🔧 Refactor (Find & Replace)" }))

    vim.keymap.set('n', base_keymap .. 'b', function()
        refactor(false)
    end, vim.tbl_extend('force', keymap_opts, { desc = "📄 Refactor Current Buffer" }))

    vim.keymap.set('n', base_keymap .. 'q', function()
        refactor(true)
    end, vim.tbl_extend('force', keymap_opts, { desc = "📋 Refactor QuickFix List" }))

    local ok, _ = pcall(require, 'refactor')
    if not ok then
        smart_notify("⚠️ Failed to load Refactor (refactor.nvim)!", vim.log.levels.WARN)
    end
end

-- Export
M.refactor = refactor
M.refactor_buffer = function() refactor(false) end
M.refactor_quickfix = function() refactor(true) end

return M
