-- Refactor: Advanced Find & Replace Plugin Module for NeoVim
-- Version: 1.1.0
-- Author: Md. Shifat Hasan (ShifatHasanGNS)
-- License: MIT

local M = {}

-- Plugin configuration with sensible defaults
local config = {
    default_flags = "w",
    default_quickfix_mode = "manual"
}

-- Global state for cancellation
local refactor_state = {
    cancelled = false
}

-- Enhanced notification with length management
local function smart_notify(message, level, max_width)
    max_width = max_width or 80
    level = level or vim.log.levels.INFO
    
    if type(message) ~= "string" then
        message = tostring(message)
    end
    
    -- Split long messages into multiple notifications
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
        
        -- Show each line as separate notification with small delay
        for i, line in ipairs(lines) do
            vim.defer_fn(function()
                vim.notify(line, level)
            end, (i - 1) * 100)  -- 100ms delay between notifications
        end
    else
        vim.notify(message, level)
    end
end

-- Enhanced flag parsing with flexible order and optional flags
local function parse_flags(flag_str)
    if not flag_str then
        flag_str = ""
    end
    
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
    
    local flags = {
        case_sensitive = flag_str:find('c') ~= nil,
        whole_word = flag_str:find('w') ~= nil,
        use_regex = flag_str:find('r') ~= nil,
        preserve_case = flag_str:find('p') ~= nil
    }
    
    return flags
end

-- Enhanced pattern building with robust escaping
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

-- Enhanced replacement string escaping
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

-- Advanced case preservation
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

function _G.refactor_preserve_case_replace(original, replacement)
    return apply_case_preservation(original, replacement)
end

-- Enhanced input function with ESC support and better UX
local function get_input_with_esc(prompt, default)
    default = default or ""
    
    -- Use inputsave/inputrestore to allow ESC to cancel input immediately
    vim.cmd('call inputsave()')
    local result = vim.fn.input(prompt, default)
    vim.cmd('call inputrestore()')
    -- If user pressed ESC, input() returns empty string and typeahead buffer is cleared
    if result == nil or result == '' then
        if not refactor_state.cancelled then
            refactor_state.cancelled = true
            smart_notify("🚫 Refactor cancelled by user (ESC)", vim.log.levels.INFO)
        end
        return nil
    end
    return result
end

-- Check for cancellation
local function check_cancelled()
    if refactor_state.cancelled then
        return true
    end
    return false
end

-- Enhanced buffer replace with smart delimiter selection
local function execute_buffer_replace(params)
    if check_cancelled() then return false end
    
    local pattern = build_search_pattern(params.find, params.flags)  
    if not pattern then return false end
    
    local replace = escape_replacement_string(params.replace, params.flags.preserve_case)
    
    local delimiter = '/'
    if pattern:find('/') or replace:find('/') then
        local delim_options = {'#', '@', '|', '!', '%'}
        for _, delim in ipairs(delim_options) do
            if not pattern:find(vim.fn.escape(delim, '\\')) and not replace:find(vim.fn.escape(delim, '\\')) then
                delimiter = delim
                break
            end
        end
        
        if delimiter ~= '/' then
            pattern = pattern:gsub('\\/', '/')
            pattern = vim.fn.escape(pattern, delimiter)
            
            if not params.flags.preserve_case then
                replace = replace:gsub('\\/', '/')
                replace = vim.fn.escape(replace, delimiter)
            end
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

-- Enhanced user input with ESC support
local function get_user_input(scope, prefill_find)
    refactor_state.cancelled = false  -- Reset cancellation state
    
    vim.cmd('redraw')
    
    -- Show help information in manageable chunks
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
    
    -- Wait a bit for notifications to show
    vim.defer_fn(function()
        if check_cancelled() then return end
        -- Get flags input
        local flags_input = get_input_with_esc("Flags [c w r p]: ", config.default_flags)
        if check_cancelled() or not flags_input then return end

        local flags = parse_flags(flags_input)
        if check_cancelled() or not flags then return end

        local flag_display = {}
        table.insert(flag_display, flags.case_sensitive and "Case-sensitive" or "Case-insensitive")
        table.insert(flag_display, flags.whole_word and "Whole-word" or "Partial-match")
        table.insert(flag_display, flags.use_regex and "RegEx" or "Literal-text")
        table.insert(flag_display, flags.preserve_case and "Preserve-case" or "Normal-case")
        smart_notify("Active: " .. table.concat(flag_display, " | "), vim.log.levels.INFO)

        local replace_mode = config.default_quickfix_mode
        if scope == "quickfix" then
            smart_notify("Modes: auto=fast+all-files, manual=precise+per-line", vim.log.levels.INFO)
            local mode_input = get_input_with_esc("Replace Mode [auto/manual]: ", replace_mode)
            if check_cancelled() or not mode_input then return end
            if mode_input == "" then
                smart_notify("🚫 No replace mode selected", vim.log.levels.INFO)
                refactor_state.cancelled = true
                return
            end
            if mode_input:lower():match("^m") then
                replace_mode = "manual"
            elseif mode_input:lower():match("^a") then
                replace_mode = "auto"
            end
        end

        local find_str = get_input_with_esc("Find: ", prefill_find or "")
        if check_cancelled() or not find_str then return end
        if find_str == "" then
            smart_notify("🚫 No find string entered", vim.log.levels.INFO)
            refactor_state.cancelled = true
            return
        end
        smart_notify("Find: '" .. find_str .. "'", vim.log.levels.INFO)

        local replace_str = get_input_with_esc("Replace: ", "")
        if check_cancelled() or not replace_str then return end
        if replace_str == "" then
            smart_notify("🚫 No replace string entered", vim.log.levels.INFO)
            refactor_state.cancelled = true
            return
        end
        smart_notify("Replace: '" .. replace_str .. "'", vim.log.levels.INFO)

        -- Continue with the refactor operation
        local params = {
            flags = flags,
            find = find_str,
            replace = replace_str,
            replace_mode = replace_mode
        }
        vim.defer_fn(function()
            if not check_cancelled() then
                M._continue_refactor(scope, params)
            end
        end, 100)
    end, 800)
    
    return nil  -- Return nil since we're handling this asynchronously
end

-- Quickfix replace with auto mode
local function execute_quickfix_replace_auto(params)
    if check_cancelled() then return false end
    
    local qf_list = vim.fn.getqflist()
    local qf_count = #qf_list
    
    if qf_count == 0 then
        smart_notify("📋 No quickfix entries found", vim.log.levels.WARN)
        return false
    end
    
    local pattern = build_search_pattern(params.find, params.flags)
    if not pattern then return false end
    
    local replace = escape_replacement_string(params.replace, params.flags.preserve_case)
    
    local delimiter = '/'
    if pattern:find('/') or replace:find('/') then
        local delim_options = {'#', '@', '|', '!', '%'}
        for _, delim in ipairs(delim_options) do
            if not pattern:find(vim.fn.escape(delim, '\\')) and not replace:find(vim.fn.escape(delim, '\\')) then
                delimiter = delim
                break
            end
        end
        
        if delimiter ~= '/' then
            pattern = pattern:gsub('\\/', '/')
            pattern = vim.fn.escape(pattern, delimiter)
            
            if not params.flags.preserve_case then
                replace = replace:gsub('\\/', '/')
                replace = vim.fn.escape(replace, delimiter)
            end
        end
    end
    
    smart_notify(string.format("⚡ AUTO MODE: Processing %d entries...", qf_count), vim.log.levels.INFO)
    
    local current_pos = vim.fn.getcurpos()
    local current_buf = vim.fn.bufnr('%')
    
    local substitute_cmd = 's' .. delimiter .. pattern .. delimiter .. replace .. delimiter .. 'g'
    if not params.flags.case_sensitive then
        substitute_cmd = substitute_cmd .. 'i'
    end
    
    local success_count = 0
    
    local ok, result = pcall(function()
        vim.cmd('cfirst')
        vim.cmd('cdo ' .. substitute_cmd)
        vim.cmd('wall')
        success_count = qf_count
    end)
    
    if not ok then
        smart_notify("⚡ Switching to individual processing...", vim.log.levels.INFO)
        
        success_count = 0
        
        for i = 1, qf_count do
            if check_cancelled() then break end
            
            local entry_ok = pcall(function()
                vim.cmd(i .. 'cc')
                vim.cmd(substitute_cmd)
                vim.cmd('write')
                success_count = success_count + 1
            end)
            
            if not entry_ok then
                -- Continue processing other entries
            end
        end
        
        ok = success_count > 0
    end
    
    pcall(function()
        if vim.fn.bufexists(current_buf) then
            vim.cmd('buffer ' .. current_buf)
            vim.fn.setpos('.', current_pos)
        end
    end)
    
    if not ok or success_count == 0 then
        smart_notify("❌ AUTO MODE failed", vim.log.levels.ERROR)
        return false
    else
        local msg = success_count == qf_count and "✅ AUTO MODE: All entries processed" or 
                    string.format("✅ AUTO MODE: %d/%d entries processed", success_count, qf_count)
        smart_notify(msg, vim.log.levels.INFO)
        vim.cmd('copen')
        return true
    end
end

-- Quickfix replace with manual mode
local function execute_quickfix_replace_manual(params)
    if check_cancelled() then return false end
    
    local qf_list = vim.fn.getqflist()
    local qf_count = #qf_list
    
    if qf_count == 0 then
        smart_notify("📋 No quickfix entries found", vim.log.levels.WARN)
        return false
    end
    
    local pattern = build_search_pattern(params.find, params.flags)
    if not pattern then return false end
    
    smart_notify(string.format("🔧 MANUAL MODE: Processing %d entries...", qf_count), vim.log.levels.INFO)
    
    local success_count = 0
    
    local original_buf = vim.fn.bufnr('%')
    local original_pos = vim.fn.getcurpos()
    
    local delimiter = '/'
    local replace = escape_replacement_string(params.replace, params.flags.preserve_case)
    if pattern:find('/') or replace:find('/') then
        local delim_options = {'#', '@', '|', '!', '%'}
        for _, delim in ipairs(delim_options) do
            if not pattern:find(vim.fn.escape(delim, '\\')) and not replace:find(vim.fn.escape(delim, '\\')) then
                delimiter = delim
                break
            end
        end
    end
    
    local buffers_to_process = {}
    for _, qf_item in ipairs(qf_list) do
        if qf_item.bufnr and qf_item.bufnr > 0 and qf_item.lnum and qf_item.lnum > 0 then
            if not buffers_to_process[qf_item.bufnr] then
                buffers_to_process[qf_item.bufnr] = {}
            end
            table.insert(buffers_to_process[qf_item.bufnr], qf_item)
        end
    end
    
    for bufnr, items in pairs(buffers_to_process) do
        if check_cancelled() then break end
        
        local filename = vim.fn.bufname(bufnr)
        local display_name = vim.fn.fnamemodify(filename, ":t")
        
        smart_notify(string.format("🔄 Processing: %s (%d locations)", display_name, #items), vim.log.levels.INFO)
        
        local ok = pcall(function()
            if not vim.fn.bufloaded(bufnr) then
                vim.cmd('badd ' .. vim.fn.fnameescape(filename))
            end
            
            vim.cmd('buffer ' .. bufnr)
            
            table.sort(items, function(a, b) return a.lnum > b.lnum end)
            
            for _, qf_item in ipairs(items) do
                if check_cancelled() then break end
                
                local cmd = string.format("%ds%s%s%s%s%sgc", 
                    qf_item.lnum, delimiter, pattern, delimiter, replace, delimiter)
                if not params.flags.case_sensitive then
                    cmd = cmd .. 'i'
                end
                
                vim.fn.cursor(qf_item.lnum, 1)
                
                local line_ok = pcall(function()
                    vim.cmd(cmd)
                end)
                
                if line_ok then
                    success_count = success_count + 1
                end
            end
            
            vim.cmd('write')
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
    
    if success_count > 0 then
        smart_notify("✅ MANUAL: " .. success_count .. " entries processed", vim.log.levels.INFO)
        vim.cmd('copen')
        return true
    else
        smart_notify("❌ MANUAL: No entries processed", vim.log.levels.ERROR)
        return false
    end
end

-- Quickfix replace dispatcher
local function execute_quickfix_replace(params)
    local mode = params.replace_mode or "auto"
    
    if mode == "manual" then
        return execute_quickfix_replace_manual(params)
    else
        local success = execute_quickfix_replace_auto(params)
        if not success then
            smart_notify("🔄 AUTO failed, trying MANUAL...", vim.log.levels.WARN)
            return execute_quickfix_replace_manual(params)
        end
        return success
    end
end

-- Continue refactor function (called after async input gathering)
function M._continue_refactor(scope, params)
    if check_cancelled() then return end
    
    local flag_chars = {}
    if params.flags.case_sensitive then table.insert(flag_chars, "c") end
    if params.flags.whole_word then table.insert(flag_chars, "w") end
    if params.flags.use_regex then table.insert(flag_chars, "r") end
    if params.flags.preserve_case then table.insert(flag_chars, "p") end
    
    local flag_str = table.concat(flag_chars, "")
    if flag_str == "" then flag_str = "none" end

    local mode_info = ""
    if scope == "quickfix" then
        local mode_icon = params.replace_mode == "auto" and "⚡" or "🔧"
        mode_info = string.format(" [%s %s]", mode_icon, params.replace_mode:upper())
    end

    smart_notify(string.format("🚀 Refactor%s [%s]: '%s' → '%s'", mode_info, flag_str, params.find, params.replace), vim.log.levels.INFO)

    local success
    if scope == "quickfix" then
        success = execute_quickfix_replace(params)
    else
        success = execute_buffer_replace(params)
    end

    if success then
        smart_notify("🎉 Refactor completed successfully!", vim.log.levels.INFO)
    else
        smart_notify("⚠️ Refactor encountered errors", vim.log.levels.WARN)
    end
end

-- Main refactor function
local function refactor(use_quickfix, prefill_find)
    local scope = use_quickfix and "quickfix" or "buffer"
    
    -- Start the input gathering process (ESC is handled by input())
    get_user_input(scope, prefill_find)
end

-- Plugin setup function
function M.setup(opts)
    opts = opts or {}

    if opts.default_flags then
        config.default_flags = opts.default_flags
    end
    if opts.default_quickfix_mode then
        config.default_quickfix_mode = opts.default_quickfix_mode
    end

    vim.api.nvim_create_user_command('Refactor', function()
        refactor(false)
    end, { desc = "Advanced Find and Replace in Current Buffer" })

    vim.api.nvim_create_user_command('RefactorQF', function()
        refactor(true)
    end, { desc = "Advanced Find and Replace in QuickFix List" })

    vim.api.nvim_create_user_command('RefactorQuickFix', function()
        refactor(true)
    end, { desc = "Advanced Find and Replace in QuickFix List" })

    local keymap_opts = { silent = true, noremap = true }
    local base_keymap = opts.keymap or '<leader>r'

    vim.keymap.set('n', base_keymap, function()
        refactor(false)
    end, vim.tbl_extend('force', keymap_opts, { desc = "🔧 Refactor (Find & Replace)" }))

    vim.keymap.set('n', base_keymap .. 'b', function()
        refactor(false)
    end, vim.tbl_extend('force', keymap_opts, { desc = "📄 Refactor Current Buffer" }))

    vim.keymap.set('n', base_keymap .. 'q', function()
        refactor(true)
    end, vim.tbl_extend('force', keymap_opts, { desc = "📋 Refactor QuickFix List" }))

    smart_notify("🔧 Refactor plugin loaded successfully!", vim.log.levels.INFO)
end

-- Export functions
M.refactor = refactor
M.refactor_buffer = function() refactor(false) end
M.refactor_quickfix = function() refactor(true) end

return M
