-- plugin/refactor.lua - Auto-loading setup for Refactor.nvim

-- Prevent loading twice
if vim.g.loaded_refactor then
    return
end
vim.g.loaded_refactor = 1

-- Only load if Neovim version is supported
if vim.fn.has('nvim-0.7') == 0 then
    vim.notify('refactor.nvim requires Neovim >= 0.7', vim.log.levels.ERROR)
    return
end

-- Auto-setup with default configuration
-- Users can override by calling require('refactor').setup() with custom opts
require('refactor').setup()
