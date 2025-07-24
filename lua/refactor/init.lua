-- Refactor: Advanced Find & Replace Plugin Module for NeoVim
-- Version: 1.0.1
-- Author: Md. Shifat Hasan (ShifatHasanGNS)
-- License: MIT

-- FIXED: QuickFix List issue resolved

local M = {}

-- Plugin configuration with sensible defaults
local config = {
    icons = {
        case = { on = "🔤", off = "🔡" },
        word = { on = "📝", off = "✏️" },
        regex = { on = "🔧", off = "📄" },
        preserve = { on = "🎨", off = "✨" }
    },
    max_selection_length = 200,  -- Maximum length for visual selections
    default_flags = "w",      -- Default flag combination
    default_quickfix_mode = "manual"  -- Default quickfix processing mode
}

-- Enhanced flag parsing with flexible order and optional flags
local function parse_flags(flag_str)
    if not flag_str then
        flag_str = ""
    end
    
    -- Trim whitespace and convert to lowercase for consistency
    flag_str = vim.trim(flag_str):lower()
    
    -- Validate that all characters are valid
    local valid_chars = { 'c', 'w', 'r', 'p' }
    local seen_chars = {}
    
    for i = 1, #flag_str do
        local char = flag_str:sub(i, i)
        if not vim.tbl_contains(valid_chars, char) then
            vim.notify(string.format("❌ Invalid flag character '%s'\nValid flags: c, w, r, p", char), vim.log.levels.ERROR)
            return nil
        end
        
        -- Check for duplicates
        if seen_chars[char] then
            vim.notify(string.format("❌ Duplicate flag character '%s'\nEach flag can only be used once", char), vim.log.levels.ERROR)
            return nil
        end
        seen_chars[char] = true
    end
    
    -- Parse flags - present = true, missing = false
    local flags = {
        case_sensitive = flag_str:find('c') ~= nil,
        whole_word = flag_str:find('w') ~= nil,
        use_regex = flag_str:find('r') ~= nil,
        preserve_case = flag_str:find('p') ~= nil
    }
    
    return flags
end

-- Enhanced pattern building with robust escaping for complex text
local function build_search_pattern(find_str, flags)
    local pattern = find_str

    -- Remove all newline characters, keep other characters as-is
    pattern = pattern:gsub('[\n\r]', '')

    -- Handle empty search
    if pattern == "" then
        vim.notify("⚠️ Empty search pattern", vim.log.levels.WARN)
        return nil
    end

    -- For literal text, escape only delimiter and backslash
    if not flags.use_regex then
        pattern = pattern:gsub('([/\\])', '\\%1')
    else
        -- For regex mode, validate the pattern
        local ok, _ = pcall(vim.fn.match, "test", pattern)
        if not ok then
            vim.notify("❌ Invalid regex pattern: " .. pattern, vim.log.levels.ERROR)
            return nil
        end
    end

    -- Add word boundaries if 'Whole Word' matching
    if flags.whole_word then
        pattern = '\\<' .. pattern .. '\\>'
    end

    -- Add 'Very Magic' prefix for RegEx
    if flags.use_regex then
        pattern = '\v' .. pattern
    end

    return pattern
end

-- Enhanced replacement string escaping for complex content
local function escape_replacement_string(replace_str, preserve_case)
    -- Remove all newline characters, keep other characters as-is
    local single_line = replace_str:gsub('[\n\r]', '')
    if preserve_case then
        return '\\=luaeval("_G.refactor_preserve_case_replace(submatch(0), \'' ..
               vim.fn.escape(single_line, "'\\") .. '\')"'
    else
        -- Only escape delimiter and backslash
        local escaped = single_line:gsub('([/\\])', '\\%1')
        return escaped
    end
end

-- Advanced case preservation with multiple patterns
local function apply_case_preservation(original, replacement)
    if original == "" or replacement == "" then
        return replacement
    end

    -- All uppercase
    if original == original:upper() and original ~= original:lower() then
        return replacement:upper()
    end

    -- All lowercase
    if original == original:lower() and original ~= original:upper() then
        return replacement:lower()
    end

    -- Title case (first letter uppercase)
    if original:sub(1, 1) == original:sub(1, 1):upper() and
        (#original == 1 or original:sub(2) == original:sub(2):lower()) then
        return replacement:sub(1, 1):upper() .. replacement:sub(2):lower()
    end

    -- Mixed case - try to preserve pattern
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

-- Global function for case preservation
function _G.refactor_preserve_case_replace(original, replacement)
    return apply_case_preservation(original, replacement)
end

-- Enhanced buffer replace with smart delimiter selection
local function execute_buffer_replace(params)
    local pattern = build_search_pattern(params.find, params.flags)  
    if not pattern then return false end
    
    local replace = escape_replacement_string(params.replace, params.flags.preserve_case)
    
    -- Smart delimiter selection
    local delimiter = '/'
    if pattern:find('/') or replace:find('/') then
        local delim_options = {'#', '@', '|', '!', '%'}
        for _, delim in ipairs(delim_options) do
            if not pattern:find(vim.fn.escape(delim, '\\')) and not replace:find(vim.fn.escape(delim, '\\')) then
                delimiter = delim
                break
            end
        end
        
        -- Re-escape for new delimiter if needed
        if delimiter ~= '/' then
            pattern = pattern:gsub('\\/', '/')
            pattern = vim.fn.escape(pattern, delimiter)
            
            if not params.flags.preserve_case then
                replace = replace:gsub('\\/', '/')
                replace = vim.fn.escape(replace, delimiter)
            end
        end
    end
    
    -- Build and execute substitute command
    local cmd = '%s' .. delimiter .. pattern .. delimiter .. replace .. delimiter .. 'gc'
    
    if not params.flags.case_sensitive then
        cmd = cmd .. 'i'  
    end
    
    vim.notify(string.format("🔍 Searching in Buffer: %s", vim.fn.expand('%:t')), vim.log.levels.INFO)
    
    local ok, result = pcall(function() vim.cmd(cmd) end)
    if not ok then
        vim.notify("❌ Replace failed: " .. tostring(result), vim.log.levels.ERROR)
        vim.notify("💡 Try using different flags or check for special characters", vim.log.levels.INFO)
        return false
    else
        vim.notify("✅ Buffer replace completed", vim.log.levels.INFO)
        return true
    end
end

-- Enhanced input with comprehensive validation
local function get_user_input(scope, prefill_find)
    local scope_icon = scope == "quickfix" and "📋" or "📄"
    local scope_text = scope == "quickfix" and "Quickfix List" or "Current Buffer"

    vim.cmd('redraw')
    vim.notify("Flag Format: [c][w][r][p] (any order, optional)", vim.log.levels.INFO)
    vim.notify("c : Case Sensitive (default: insensitive)\nw : Whole Word Match (default: partial)\nr : RegEx Pattern (default: literal)\np : Preserve Case (default: don't preserve)", vim.log.levels.INFO)
    vim.notify("Examples:\n• 'cw' = Case-sensitive, Whole word\n• 'p' = Preserve case only\n• 'wr' = Whole word + RegEx\n• '' = All defaults (case-insens, partial, literal, no-preserve)", vim.log.levels.INFO)
    
    local flags_input = vim.fn.input("Flags [c w r p]: ", config.default_flags)
    local flags = parse_flags(flags_input)
    if not flags then
        vim.notify("🚫 Refactor cancelled: Invalid flag", vim.log.levels.INFO)
        return nil
    end
    
    -- Build display string for current flags
    local flag_display = {}
    if flags.case_sensitive then table.insert(flag_display, "Case-sensitive") else table.insert(flag_display, "Case-insensitive") end
    if flags.whole_word then table.insert(flag_display, "Whole word") else table.insert(flag_display, "Partial match") end
    if flags.use_regex then table.insert(flag_display, "RegEx") else table.insert(flag_display, "Literal text") end
    if flags.preserve_case then table.insert(flag_display, "Preserve case") else table.insert(flag_display, "Don't preserve case") end
    
    vim.notify("Active flags: " .. table.concat(flag_display, " | "), vim.log.levels.INFO)

    if scope == "quickfix" then
        vim.notify("Choose Replace Mode: auto (fast, all files) or manual (precise, per line)", vim.log.levels.INFO)
    end

    local replace_mode = config.default_quickfix_mode
    if scope == "quickfix" then
        local mode_input = vim.fn.input("Replace Mode [auto/manual]: ", replace_mode)
        if mode_input == "" then
            vim.notify("🚫 Refactor cancelled: No replace mode selected", vim.log.levels.INFO)
            return nil
        end
        if mode_input:lower():match("^m") then
            replace_mode = "manual"
        elseif mode_input:lower():match("^a") then
            replace_mode = "auto"
        end
    end

    local find_str = vim.fn.input("Find: ", prefill_find or "")
    if find_str == "" then
        vim.notify("🚫 Refactor cancelled: No find string entered", vim.log.levels.INFO)
        return nil
    end
    vim.notify("Find string: '" .. find_str .. "'", vim.log.levels.INFO)
    local replace_str = vim.fn.input("Replace: ")
    if replace_str == "" then
        vim.notify("🚫 Refactor cancelled: No replace string entered", vim.log.levels.INFO)
        return nil
    end
    vim.notify("Replace string: '" .. replace_str .. "'", vim.log.levels.INFO)

    return {
        flags = flags,
        find = find_str,
        replace = replace_str,
        replace_mode = replace_mode
    }
end

-- FIXED: Quickfix replace with auto mode
local function execute_quickfix_replace_auto(params)
    local qf_list = vim.fn.getqflist()
    local qf_count = #qf_list
    
    if qf_count == 0 then
        vim.notify("📋 No quickfix entries found", vim.log.levels.WARN)
        return false
    end
    
    local pattern = build_search_pattern(params.find, params.flags)
    if not pattern then return false end
    
    local replace = escape_replacement_string(params.replace, params.flags.preserve_case)
    
    -- Smart delimiter selection for substitute command
    local delimiter = '/'
    if pattern:find('/') or replace:find('/') then
        local delim_options = {'#', '@', '|', '!', '%'}
        for _, delim in ipairs(delim_options) do
            if not pattern:find(vim.fn.escape(delim, '\\')) and not replace:find(vim.fn.escape(delim, '\\')) then
                delimiter = delim
                break
            end
        end
        
        -- Re-escape for new delimiter if needed
        if delimiter ~= '/' then
            pattern = pattern:gsub('\\/', '/')
            pattern = vim.fn.escape(pattern, delimiter)
            
            if not params.flags.preserve_case then
                replace = replace:gsub('\\/', '/')
                replace = vim.fn.escape(replace, delimiter)
            end
        end
    end
    
    vim.notify(string.format("⚡ AUTO MODE: Processing %d quickfix entries...", qf_count), vim.log.levels.INFO)
    
    -- Save current state
    local current_pos = vim.fn.getcurpos()
    local current_buf = vim.fn.bufnr('%')
    
    -- Build substitute command with proper flags
    local substitute_cmd = 's' .. delimiter .. pattern .. delimiter .. replace .. delimiter .. 'g'
    if not params.flags.case_sensitive then
        substitute_cmd = substitute_cmd .. 'i'
    end
    
    local success_count = 0
    local error_count = 0
    
    -- Process each quickfix entry individually for better control
    local ok, result = pcall(function()
        -- Go to first quickfix entry
        vim.cmd('cfirst')
        
        -- Use cdo to execute command on each quickfix entry
        vim.cmd('cdo ' .. substitute_cmd)
        
        -- Save all modified buffers
        vim.cmd('wall')
        
        success_count = qf_count
    end)
    
    -- Alternative approach if cdo fails - process manually
    if not ok then
        vim.notify("⚡ Switching to individual entry processing...", vim.log.levels.INFO)
        
        success_count = 0
        error_count = 0
        
        for i = 1, qf_count do
            local entry_ok = pcall(function()
                vim.cmd(i .. 'cc')  -- Go to i-th quickfix entry
                vim.cmd(substitute_cmd)
                vim.cmd('write')
                success_count = success_count + 1
            end)
            
            if not entry_ok then
                error_count = error_count + 1
            end
        end
        
        ok = success_count > 0
    end
    
    -- Restore state
    pcall(function()
        if vim.fn.bufexists(current_buf) then
            vim.cmd('buffer ' .. current_buf)
            vim.fn.setpos('.', current_pos)
        end
    end)
    
    if not ok or success_count == 0 then
        vim.notify("❌ AUTO MODE failed: " .. tostring(result), vim.log.levels.ERROR)
        return false
    else
        local msg = success_count == qf_count and "✅ AUTO MODE: All entries processed" or 
                    string.format("✅ AUTO MODE: %d/%d entries processed", success_count, qf_count)
        vim.notify(msg, vim.log.levels.INFO)
        vim.cmd('copen')
        return true
    end
end

-- FIXED: Quickfix replace with manual mode
local function execute_quickfix_replace_manual(params)
    local qf_list = vim.fn.getqflist()
    local qf_count = #qf_list
    
    if qf_count == 0 then
        vim.notify("📋 No quickfix entries found", vim.log.levels.WARN)
        return false
    end
    
    local pattern = build_search_pattern(params.find, params.flags)
    if not pattern then return false end
    
    vim.notify(string.format("🔧 MANUAL MODE: Processing %d quickfix entries...", qf_count), vim.log.levels.INFO)
    
    local success_count = 0
    local error_count = 0
    
    local original_buf = vim.fn.bufnr('%')
    local original_pos = vim.fn.getcurpos()
    
    -- Smart delimiter selection
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
    
    -- Group entries by buffer to process files efficiently
    local buffers_to_process = {}
    for _, qf_item in ipairs(qf_list) do
        if qf_item.bufnr and qf_item.bufnr > 0 and qf_item.lnum and qf_item.lnum > 0 then
            if not buffers_to_process[qf_item.bufnr] then
                buffers_to_process[qf_item.bufnr] = {}
            end
            table.insert(buffers_to_process[qf_item.bufnr], qf_item)
        end
    end
    
    -- Process each buffer
    for bufnr, items in pairs(buffers_to_process) do
        local filename = vim.fn.bufname(bufnr)
        local display_name = vim.fn.fnamemodify(filename, ":t")
        
        vim.notify(string.format("🔄 Processing file: %s (%d locations)", display_name, #items), vim.log.levels.INFO)
        
        local ok = pcall(function()
            -- Load the buffer if not already loaded
            if not vim.fn.bufloaded(bufnr) then
                vim.cmd('badd ' .. vim.fn.fnameescape(filename))
            end
            
            vim.cmd('buffer ' .. bufnr)
            
            -- Sort items by line number in descending order to avoid line number shifts
            table.sort(items, function(a, b) return a.lnum > b.lnum end)
            
            -- Process each line in this buffer
            for _, qf_item in ipairs(items) do
                local cmd = string.format("%ds%s%s%s%s%sgc", 
                    qf_item.lnum, delimiter, pattern, delimiter, replace, delimiter)
                if not params.flags.case_sensitive then
                    cmd = cmd .. 'i'
                end
                
                -- Move to the specific line
                vim.fn.cursor(qf_item.lnum, 1)
                
                local line_ok = pcall(function()
                    vim.cmd(cmd)
                end)
                
                if line_ok then
                    success_count = success_count + 1
                else
                    error_count = error_count + 1
                end
            end
            
            -- Save the buffer
            vim.cmd('write')
        end)
        
        if not ok then
            error_count = error_count + #items
            vim.notify(string.format("❌ Failed to process file: %s", display_name), vim.log.levels.ERROR)
        else
            vim.notify(string.format("✅ Successfully processed: %s", display_name), vim.log.levels.INFO)
        end
    end
    
    -- Restore original state
    pcall(function()
        if vim.fn.bufexists(original_buf) then
            vim.cmd('buffer ' .. original_buf)
            vim.fn.setpos('.', original_pos)
        end
    end)
    
    if success_count > 0 then
        vim.notify(string.format("✅ MANUAL MODE: Processed %d entries (%d errors)", 
            success_count, error_count), vim.log.levels.INFO)
        vim.cmd('copen')
        return true
    else
        vim.notify("❌ MANUAL MODE: No entries processed successfully", vim.log.levels.ERROR)
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
            vim.notify("🔄 AUTO MODE failed, switching to MANUAL MODE...", vim.log.levels.WARN)
            return execute_quickfix_replace_manual(params)
        end
        return success
    end
end

-- Main refactor function
local function refactor(use_quickfix, prefill_find)
    local scope = use_quickfix and "quickfix" or "buffer"
    local params = get_user_input(scope, prefill_find)

    if not params then return end

    -- Show summary
    local flag_chars = {}
    if params.flags.case_sensitive then table.insert(flag_chars, "c") end
    if params.flags.whole_word then table.insert(flag_chars, "w") end
    if params.flags.use_regex then table.insert(flag_chars, "r") end
    if params.flags.preserve_case then table.insert(flag_chars, "p") end
    
    local flag_str = table.concat(flag_chars, "")
    if flag_str == "" then flag_str = "none" end

    local mode_info = ""
    if use_quickfix then
        local mode_icon = params.replace_mode == "auto" and "⚡" or "🔧"
        mode_info = string.format(" [%s %s]", mode_icon, params.replace_mode:upper())
    end

    vim.notify(string.format("🚀 Refactor%s - [%s]: '%s' ⟶ '%s'", mode_info, flag_str, params.find, params.replace), vim.log.levels.INFO)

    local success
    if use_quickfix then
        success = execute_quickfix_replace(params)
    else
        success = execute_buffer_replace(params)
    end

    if success then
        vim.notify("🎉 Refactor operation completed successfully!", vim.log.levels.INFO)
    else
        vim.notify("⚠️ Refactor operation encountered errors", vim.log.levels.WARN)
    end
end

-- Plugin setup function
function M.setup(opts)
    opts = opts or {}

    -- Merge user config with defaults
    if opts.icons then
        config.icons = vim.tbl_deep_extend("force", config.icons, opts.icons)
    end
    if opts.max_selection_length then
        config.max_selection_length = opts.max_selection_length
    end
    if opts.default_flags then
        config.default_flags = opts.default_flags
    end
    if opts.default_quickfix_mode then
        config.default_quickfix_mode = opts.default_quickfix_mode
    end

    -- Create user commands
    vim.api.nvim_create_user_command('Refactor', function()
        refactor(false)
    end, { desc = "Advanced Find and Replace in Current Buffer" })

    vim.api.nvim_create_user_command('RefactorQF', function()
        refactor(true)
    end, { desc = "Advanced Find and Replace in QuickFix List" })

    vim.api.nvim_create_user_command('RefactorQuickFix', function()
        refactor(true)
    end, { desc = "Advanced Find and Replace in QuickFix List" })

    -- Setup keymaps (normal mode only)
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

    -- Check if plugin is loaded
    local ok, _ = pcall(require, 'refactor')
    if not ok then
        vim.notify("⚠️ Failed to load Refactor plugin! Use ", vim.log.levels.ERROR)
    end
end

-- Export functions
M.refactor = refactor
M.refactor_buffer = function() refactor(false) end
M.refactor_quickfix = function() refactor(true) end

return M
