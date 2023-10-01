return {

	"nvim-lua/popup.nvim", -- An implementation of the Popup API from vim in Neovim
	"nvim-lua/plenary.nvim", -- Useful lua functions used ny lots of plugins
	--  "lunarvim/Onedarker.nvim",
	"navarasu/onedark.nvim",
	"windwp/nvim-autopairs", -- Autopairs, integrates with both cmp and treesitter
	"numToStr/Comment.nvim", -- Easily comment stuff
	"kyazdani42/nvim-web-devicons",
	"kyazdani42/nvim-tree.lua",
	"akinsho/bufferline.nvim",
	"nvim-lualine/lualine.nvim",
	"akinsho/toggleterm.nvim",
	"luukvbaal/nnn.nvim",

	{
		"norcalli/nvim-colorizer.lua",
		config = function()
			require("user.colorizer")
		end,
		ft = { "html", "css", "sass", "javascript", "typescriptreact", "javascriptreact" },
		cmd = "ColorizerToggle",
	},
	{
		"glepnir/dashboard-nvim",
		config = function()
			require("user.dashboard")
		end,
		-- Only load when no arguments
		event = function()
			if vim.fn.argc() == 0 then
				return "VimEnter"
			end
		end,
		cmd = "Dashboard",
	},
	{
		"iamcco/markdown-preview.nvim",
		build = function()
			vim.fn["mkdp#util#install"]()
		end,
		ft = { "markdown" },
		cmd = { "MarkdownPreviewToggle", "MarkdownPreview" },
	},

    {
        'lewis6991/gitsigns.nvim',
        cmd = 'Gitsigns',
        event = 'BufWinEnter',
        config = function()
            require('user.gitsigns')
        end,
    },
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
    "nvimtools/none-ls.nvim",
	-- "jose-elias-alvarez/null-ls.nvim", -- LSP di
--    "madhur/null-ls.nvim",

	-- telescope
	"nvim-telescope/telescope.nvim",
	"nvim-telescope/telescope-media-files.nvim",

	"nvim-treesitter/nvim-treesitter",
	build = function()
		pcall(require("nvim-treesitter.install").update({
			with_sync = true,
		}))
	end,
}
