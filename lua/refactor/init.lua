-- Refactor: Advanced Find & Replace Plugin Module for NeoVim
-- Version: 1.0.0
-- Author: Md. Shifat Hasan (ShifatHasanGNS)
-- License: MIT

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
    default_flags = "cWrp",      -- Default flag combination
    default_quickfix_mode = "manual"  -- Default quickfix processing mode
}

-- Enhanced flag parsing with validation and helpful errors
local function parse_flags(flag_str)
    if not flag_str or flag_str == "" then
        vim.notify("❌ Empty flag!\nUse Format: [C/c][W/w][R/r][P/p]\nExample: 'cWrp'", vim.log.levels.ERROR)
        return nil
    end

    if #flag_str ~= 4 then
        vim.notify("❌ Flag must have exactly 4 characters!\nFormat: [C/c][W/w][R/r][P/p]\nExample: 'cWrp'", vim.log.levels.ERROR)
        return nil
    end

    local chars = {flag_str:match("(.)(.)(.)(.)") }
    local valid_chars = {
        [1] = { 'C', 'c' }, -- Case
        [2] = { 'W', 'w' }, -- Word  
        [3] = { 'R', 'r' }, -- RegEx
        [4] = { 'P', 'p' }  -- Preserve
    }

    -- Validate each character
    for i, char in ipairs(chars) do
        if not vim.tbl_contains(valid_chars[i], char) then
            local expected = table.concat(valid_chars[i], "/")
            vim.notify(string.format("❌ Invalid character '%s' at position %d\nExpected: %s", char, i, expected), vim.log.levels.ERROR)
            return nil
        end
    end

    local flags = {
        case_sensitive = chars[1] == 'C',
        whole_word = chars[2] == 'W', 
        use_regex = chars[3] == 'R',
        preserve_case = chars[4] == 'P'
    }

    return flags
end

-- Beautiful flag display with icons and descriptions
local function format_flags_display(flags)
    if not flags then return "" end

    local parts = {
        string.format("%s %s", 
            flags.case_sensitive and config.icons.case.on or config.icons.case.off,
            flags.case_sensitive and "Case-Sensitive" or "Case-Insensitive"
        ),
        string.format("%s %s", 
            flags.whole_word and config.icons.word.on or config.icons.word.off,
            flags.whole_word and "Exact Word Match" or "Partial Word Match"
        ),
        string.format("%s %s", 
            flags.use_regex and config.icons.regex.on or config.icons.regex.off,
            flags.use_regex and "RegEx Mode" or "Literal Text"
        ),
        string.format("%s %s", 
            flags.preserve_case and config.icons.preserve.on or config.icons.preserve.off,
            flags.preserve_case and "Preserve Case" or "Exact Replace"
        )
    }

    return table.concat(parts, " | ")
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
    local flags_input = vim.fn.input("Flags [C/c W/w R/r P/p]: ", config.default_flags)
    if flags_input == "" then return nil end
    local flags = parse_flags(flags_input)
    if not flags then return nil end

    local replace_mode = config.default_quickfix_mode
    if scope == "quickfix" then
        local mode_input = vim.fn.input("Replace Mode [auto/manual]: ", replace_mode)
        if mode_input == "" then return nil end
        if mode_input:lower():match("^m") then
            replace_mode = "manual"
        elseif mode_input:lower():match("^a") then
            replace_mode = "auto"
        end
    end

    local find_str = vim.fn.input("Find: ", prefill_find or "")
    if find_str == "" then return nil end
    local replace_str = vim.fn.input("Replace: ")
    if replace_str == "" then return nil end

    return {
        flags = flags,
        find = find_str,
        replace = replace_str,
        replace_mode = replace_mode
    }
end

-- Quickfix replace with auto mode
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
    local substitute_cmd = 's/' .. pattern .. '/' .. replace .. '/gc'
    
    if not params.flags.case_sensitive then
        substitute_cmd = substitute_cmd .. 'i'
    end
    
    local cmd = 'cfdo ' .. substitute_cmd
    
    vim.notify(string.format("⚡ AUTO MODE: Processing %d quickfix entries...", qf_count), vim.log.levels.INFO)
    
    local current_pos = vim.fn.getcurpos()
    local current_buf = vim.fn.bufnr('%')
    
    local ok, result = pcall(function() 
        vim.cmd('cfirst')
        vim.cmd(cmd)
    end)
    
    pcall(function()
        if vim.fn.bufexists(current_buf) then
            vim.cmd('buffer ' .. current_buf)
            vim.fn.setpos('.', current_pos)
        end
    end)
    
    if not ok then
        vim.notify("❌ AUTO MODE failed: " .. tostring(result), vim.log.levels.ERROR)
        return false
    else
        vim.notify("✅ AUTO MODE: Quickfix replace completed", vim.log.levels.INFO)
        vim.cmd('copen')
        return true
    end
end

-- Quickfix replace with manual mode
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
    
    local processed_files = {}
    local success_count = 0
    local error_count = 0
    
    local original_buf = vim.fn.bufnr('%')
    local original_pos = vim.fn.getcurpos()
    
    -- Process only the specific lines referenced by the quickfix list
    for _, qf_item in ipairs(qf_list) do
        if qf_item.bufnr and qf_item.bufnr > 0 and qf_item.lnum and qf_item.lnum > 0 then
            local filename = vim.fn.bufname(qf_item.bufnr)
            local display_name = vim.fn.fnamemodify(filename, ":t")
            local ok = pcall(function()
                vim.cmd('buffer ' .. qf_item.bufnr)
                local replace = escape_replacement_string(params.replace, params.flags.preserve_case)
                local cmd = string.format("%ds/%s/%s/gc", qf_item.lnum, pattern, replace)
                if not params.flags.case_sensitive then
                    cmd = cmd .. 'i'
                end
                vim.cmd(cmd)
                success_count = success_count + 1
            end)
            if not ok then
                error_count = error_count + 1
                vim.notify("❌ Failed to process: " .. display_name, vim.log.levels.ERROR)
            end
        end
    end
    
    -- Restore state
    pcall(function()
        if vim.fn.bufexists(original_buf) then
            vim.cmd('buffer ' .. original_buf)
            vim.fn.setpos('.', original_pos)
        end
    end)
    
    if success_count > 0 then
        vim.notify(string.format("✅ MANUAL MODE: Processed %d buffers (%d errors)", 
            success_count, error_count), vim.log.levels.INFO)
        vim.cmd('copen')
        return true
    else
        vim.notify("❌ MANUAL MODE: No buffers processed successfully", vim.log.levels.ERROR)
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
    local flag_str = string.format("%s%s%s%s",
        params.flags.case_sensitive and "C" or "c",
        params.flags.whole_word and "W" or "w", 
        params.flags.use_regex and "R" or "r",
        params.flags.preserve_case and "P" or "p"
    )

    local mode_info = ""
    if use_quickfix then
        local mode_icon = params.replace_mode == "auto" and "⚡" or "🔧"
        mode_info = string.format(" [%s %s]", mode_icon, params.replace_mode:upper())
    end

    vim.notify(string.format("🚀 Refactor%s - [%s]: '%s' → '%s'", 
        mode_info, flag_str, params.find, params.replace), vim.log.levels.INFO)

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
