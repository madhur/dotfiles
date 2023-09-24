return {

    "nvim-lua/popup.nvim", -- An implementation of the Popup API from vim in Neovim
    "nvim-lua/plenary.nvim", -- Useful lua functions used ny lots of plugins
    "lunarvim/Onedarker.nvim",
    "windwp/nvim-autopairs", -- Autopairs, integrates with both cmp and treesitter
    "numToStr/Comment.nvim", -- Easily comment stuff
    "kyazdani42/nvim-web-devicons",
    'kyazdani42/nvim-tree.lua',
    "akinsho/bufferline.nvim",
    "nvim-lualine/lualine.nvim",
    "akinsho/toggleterm.nvim",
    "luukvbaal/nnn.nvim",

--    "folke/which-key.nvim",

    "hrsh7th/nvim-cmp", -- The completion plugin
   
    -- I dont wan't buffer completion
    --    "hrsh7th/cmp-buffer", -- buffer completions
    "hrsh7th/cmp-path", -- path completions
    "hrsh7th/cmp-cmdline", -- cmdline completion
    "saadparwaiz1/cmp_luasnip", -- snippet compl
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-nvim-lua",

    -- snippets
    "L3MON4D3/LuaSnip", -- snippet engine
    "rafamadriz/friendly-snippets", -- a bunch o

    -- LSP
    "neovim/nvim-lspconfig", -- enable LSP
    "williamboman/mason.nvim", -- simple to use 
    "williamboman/mason-lspconfig.nvim", -- simp
    "jose-elias-alvarez/null-ls.nvim", -- LSP di

    -- telescope
    "nvim-telescope/telescope.nvim",
    "nvim-telescope/telescope-media-files.nvim",

    "nvim-treesitter/nvim-treesitter",
    build = function()
        pcall(require('nvim-treesitter.install').update {
            with_sync = true
        })
    end

}
