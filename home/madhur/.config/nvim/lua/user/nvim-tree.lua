-- following options are the default
-- each of these are documented in `:help nvim-tree.OPTION_NAME`

local status_ok, nvim_tree = pcall(require, "nvim-tree")
if not status_ok then
    vim.notify("nvim-tree not found")
    return
end

-- local config_status_ok, nvim_tree_config = pcall(require, "nvim-tree.config")
-- if not config_status_ok then
--     vim.notify("nvim-tree.config not found")
--     return
-- end
--
-- local tree_cb = nvim_tree_config.nvim_tree_callback

-- empty setup using defaults

-- disable netrw at the very start of your init.lua
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

require("nvim-tree").setup()

