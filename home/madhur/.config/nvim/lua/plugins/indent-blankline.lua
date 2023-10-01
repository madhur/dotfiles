

return {
	"lukas-reineke/indent-blankline.nvim",
	main = "ibl",
	event = { "BufReadPre", "BufNewFile" },
	opts = {
        indent = { char = "│" , highlight = { "LineNr"} },
        whitespace = { highlight = { "Whitespace", "NonText" } },
		scope = { enabled = true },
		buftype_exclude = { "telescope", "terminal", "nofile", "quickfix", "prompt" },
		filetype_exclude = {
			"starter",
			"Trouble",
			"TelescopePrompt",
			"Float",
			"OverseerForm",
			"lspinfo",
			"checkhealth",
			"help",
			"man",
			"",
		},
	},
}
