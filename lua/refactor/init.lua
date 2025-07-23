-- lua/refactor/init.lua - Advanced Find & Replace Plugin Module

local M = {}

-- UI/UX Configuration
local config = {
    -- Visual indicators for different modes
    icons = {
        case = { on = "🔤", off = "🔡" },
        word = { on = "📝", off = "✏️" },
        regex = { on = "🔧", off = "📄" },
        preserve = { on = "🎨", off = "✨" }
    }
}

-- Enhanced flag parsing with validation and helpful errors
local function parse_flags(flag_str)
    if not flag_str or flag_str == "" then
        vim.notify("❌ Empty flag! Use format: CWRP (e.g., 'cWrp')", vim.log.levels.ERROR)
        return nil
    end
    
    if #flag_str ~= 4 then
        vim.notify("❌ Flag must be exactly 4 characters!\nFormat: [C/c][W/w][R/r][P/p]\nExample: 'cWrp'", vim.log.levels.ERROR)
        return nil
    end
    
    local chars = {flag_str:match("(.)(.)(.)(.)") }
    local valid_chars = {
        [1] = { 'C', 'c' }, -- Case
        [2] = { 'W', 'w' }, -- Word  
        [3] = { 'R', 'r' }, -- Regex
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
            flags.whole_word and "Whole Words" or "Partial Match"
        ),
        string.format("%s %s", 
            flags.use_regex and config.icons.regex.on or config.icons.regex.off,
            flags.use_regex and "Regex Mode" or "Literal Text"
        ),
        string.format("%s %s", 
            flags.preserve_case and config.icons.preserve.on or config.icons.preserve.off,
            flags.preserve_case and "Preserve Case" or "Exact Replace"
        )
    }
    
    return table.concat(parts, " | ")
end

-- Smart pattern building with better regex handling
local function build_search_pattern(find_str, flags)
    local pattern = find_str
    
    -- Handle empty search
    if pattern == "" then
        vim.notify("⚠️  Empty search pattern", vim.log.levels.WARN)
        return pattern
    end
    
    -- Escape special characters if not using regex
    if not flags.use_regex then
        pattern = vim.fn.escape(pattern, '/\\^$.*~[]')
    else
        -- Validate regex pattern
        local ok, _ = pcall(vim.fn.match, "test", pattern)
        if not ok then
            vim.notify("❌ Invalid regex pattern: " .. pattern, vim.log.levels.ERROR)
            return nil
        end
    end
    
    -- Add word boundaries if whole word matching
    if flags.whole_word then
        pattern = '\\<' .. pattern .. '\\>'
    end
    
    -- Add very magic prefix for regex
    if flags.use_regex then
        pattern = '\\v' .. pattern
    end
    
    return pattern
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
    if original:sub(1,1) == original:sub(1,1):upper() and 
       (#original == 1 or original:sub(2) == original:sub(2):lower()) then
        return replacement:sub(1,1):upper() .. replacement:sub(2):lower()
    end
    
    -- Mixed case - try to preserve pattern
    local upper_ratio = 0
    for i = 1, #original do
        if original:sub(i,i):match("%u") then
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

-- Enhanced input with better prompts and validation
local function get_user_input(scope)
    local scope_icon = scope == "quickfix" and "📋" or "📄"
    local scope_text = scope == "quickfix" and "Quickfix List" or "Current Buffer"
    
    -- Clear command line
    vim.cmd('redraw')
    
    -- Get flags with helpful prompt
    print(string.format("🔧 Refactor Mode: %s %s", scope_icon, scope_text))
    print("📋 Flag Format: [Case][Word][Regex][Preserve]")
    print("   Examples: cWrp (common), CWRp (precise), cWRp (advanced)")
    
    local flags_input = vim.fn.input("🏁 Flags: ", "cWrp")
    
    if flags_input == "" then 
        vim.notify("🚫 Operation cancelled", vim.log.levels.INFO)
        return nil 
    end
    
    local flags = parse_flags(flags_input)
    if not flags then return nil end
    
    -- Show flag interpretation
    print("\n" .. format_flags_display(flags))
    
    -- Get find string
    local find_str = vim.fn.input("🔍 Find: ")
    
    if find_str == "" then 
        vim.notify("🚫 Operation cancelled", vim.log.levels.INFO)
        return nil 
    end
    
    -- Get replace string
    local replace_str = vim.fn.input("🔄 Replace: ")
    
    -- Show preview
    print(string.format("\n📋 Preview: '%s' → '%s'", find_str, replace_str))
    
    return {
        flags = flags,
        find = find_str,
        replace = replace_str
    }
end

-- Global function for case preservation (optimized)
function _G.refactor_preserve_case_replace(original, replacement)
    return apply_case_preservation(original, replacement)
end

-- Enhanced buffer replace with better error handling
local function execute_buffer_replace(params)
    local pattern = build_search_pattern(params.find, params.flags)  
    if not pattern then return end
    
    local replace = params.replace
    
    -- Apply case preservation if enabled
    if params.flags.preserve_case then
        replace = '\\=luaeval("_G.refactor_preserve_case_replace(_A[1], \'' .. 
                 vim.fn.escape(params.replace, "'\\") .. '\')", submatch(0))'
    end
    
    -- Build and execute substitute command
    local cmd = '%s/' .. pattern .. '/' .. replace .. '/gc'
    
    if not params.flags.case_sensitive then
        cmd = cmd .. 'i'  
    end
    
    vim.notify(string.format("🔍 Searching in buffer: %s", vim.fn.expand('%:t')), vim.log.levels.INFO)
    
    local ok, result = pcall(function() vim.cmd(cmd) end)
    if not ok then
        vim.notify("❌ Replace failed: " .. result, vim.log.levels.ERROR)
    end
end

-- Enhanced quickfix replace with progress indication
local function execute_quickfix_replace(params)
    local qf_list = vim.fn.getqflist()
    local qf_count = #qf_list
    
    if qf_count == 0 then
        vim.notify("📋 No quickfix entries found", vim.log.levels.WARN)
        return
    end
    
    local pattern = build_search_pattern(params.find, params.flags)
    if not pattern then return end
    
    local replace = params.replace
    
    if params.flags.preserve_case then
        replace = '\\=luaeval("_G.refactor_preserve_case_replace(_A[1], \'' .. 
                 vim.fn.escape(params.replace, "'\\") .. '\')", submatch(0))'
    end
    
    local cmd = 'cdo s/' .. pattern .. '/' .. replace .. '/gc'
    
    if not params.flags.case_sensitive then
        cmd = cmd .. 'i'
    end
    
    vim.notify(string.format("📋 Processing %d quickfix entries...", qf_count), vim.log.levels.INFO)
    
    local ok, result = pcall(function() vim.cmd(cmd) end)
    if not ok then
        vim.notify("❌ Quickfix replace failed: " .. result, vim.log.levels.ERROR)
    else
        vim.notify("✅ Quickfix replace completed", vim.log.levels.INFO)
    end
end

-- Main refactor function with enhanced UX
local function refactor(use_quickfix)
    local scope = use_quickfix and "quickfix" or "buffer"
    local params = get_user_input(scope)
    
    if not params then return end
    
    -- Final confirmation with summary
    local flag_str = string.format("%s%s%s%s",
        params.flags.case_sensitive and "C" or "c",
        params.flags.whole_word and "W" or "w", 
        params.flags.use_regex and "R" or "r",
        params.flags.preserve_case and "P" or "p"
    )
    
    vim.notify(string.format("🚀 Starting refactor [%s]: '%s' → '%s'", 
        flag_str, params.find, params.replace), vim.log.levels.INFO)
    
    if use_quickfix then
        execute_quickfix_replace(params)
    else
        execute_buffer_replace(params)
    end
end

-- Plugin setup function
function M.setup(opts)
    opts = opts or {}
    
    -- Create user commands for additional access
    vim.api.nvim_create_user_command('Refactor', function()
        refactor(false)
    end, { desc = "Advanced find and replace in buffer" })
    
    vim.api.nvim_create_user_command('RefactorQF', function()
        refactor(true)
    end, { desc = "Advanced find and replace in quickfix" })
    
    -- Setup enhanced keymaps with descriptions
    local keymap_opts = { silent = true }
    local base_keymap = opts.keymap or '<leader>r'
    
    vim.keymap.set('n', base_keymap, function()
        refactor(false)
    end, vim.tbl_extend('force', keymap_opts, { desc = "🔧 Refactor in current buffer" }))
    
    vim.keymap.set('n', base_keymap .. 'q', function()
        refactor(true)
    end, vim.tbl_extend('force', keymap_opts, { desc = "📋 Refactor in quickfix list" }))
    
    -- Additional convenience mappings
    vim.keymap.set('v', base_keymap, function()
        -- Get visual selection for find text
        local old_reg = vim.fn.getreg('"')
        vim.cmd('normal! gvy')
        local selected = vim.fn.getreg('"')
        vim.fn.setreg('"', old_reg)
        
        -- Pre-populate find field (mock implementation)
        vim.notify("🔍 Selected text: " .. selected, vim.log.levels.INFO)
        refactor(false)
    end, vim.tbl_extend('force', keymap_opts, { desc = "🔧 Refactor with visual selection" }))
    
    vim.notify("🚀 Advanced Refactor plugin loaded! Use " .. base_keymap .. " or :Refactor", vim.log.levels.INFO)
end

-- Export main functions for direct use
M.refactor = refactor
M.refactor_buffer = function() refactor(false) end
M.refactor_quickfix = function() refactor(true) end

return M
