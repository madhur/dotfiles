local configs = require("nvim-treesitter.configs")
configs.setup {
  ensure_installed = "all",
  sync_install = false, 
  ignore_install = { "" }, -- List of parsers to ignore installing
  highlight = {
    enable = true, -- false will disable the whole extension
    --disable = { "" }, -- list of language that will be disabled
    disable = function(lang, bufnr) -- Disable in large C++ buffers
        return lang == "json" -- and api.nvim_buf_line_count(bufnr) > 50000
    end,
    additional_vim_regex_highlighting = true,

  },
  indent = { enable = true, disable = { "" } },
}
