local M = {}

function M.check()
    vim.health.start("refactor.nvim")
    
    -- Check Neovim version
    if vim.fn.has('nvim-0.7') == 1 then
        vim.health.ok("Neovim version >= 0.7")
    else
        vim.health.error("Neovim version < 0.7")
    end
    
    -- Check if plugin is loaded
    local ok, _ = pcall(require, 'refactor')
    if ok then
        vim.health.ok("refactor.nvim loaded successfully")
    else
        vim.health.error("refactor.nvim failed to load")
    end
end

return M
