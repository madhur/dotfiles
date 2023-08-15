local status_ok, whichkey = pcall(require, "which-key")
if not status_ok then
    return
end

local config = {
    setup = {
        plugins = {
            marks = true, -- shows a list of your marks on ' and `
            registers = true, -- shows your registers on " in NORMAL or <C-r> in INSERT mode
            presets = {
                operators = true, -- adds help for operators like d, y, ...
                motions = true, -- adds help for motions
                text_objects = true, -- help for text objects triggered after entering an operator
                windows = true, -- default bindings on <c-w>
                nav = true, -- misc bindings to work with windows
                z = true, -- bindings for folds, spelling and others prefixed with z
                g = true -- bindings for prefixed with g
            },
            spelling = {
                enabled = true,
                suggestions = 20
            } -- use which-key for spelling hints
        },
        operators = {
            gc = "Comments"
        },
        motions = {
            count = true
        },
        popup_mappings = {
            scroll_down = "<c-d>", -- binding to scroll down inside the popup
            scroll_up = "<c-u>" -- binding to scroll up inside the popup
        },
        icons = {
            breadcrumb = "»", -- symbol used in the command line area that shows your active key combo
            separator = "➜", -- symbol used between a key and it's label
            group = "" -- symbol prepended to a group
        },
        window = {
            border = "none", -- none, single, double, shadow
            position = "bottom", -- bottom, top
            margin = {1, 0, 1, 0}, -- extra window margin [top, right, bottom, left]
            padding = {2, 2, 2, 2}, -- extra window padding [top, right, bottom, left]
            winblend = 0,
            zindex = 1000 -- positive value to position WhichKey above other floating windows.
        },
        layout = {
            height = {
                min = 4,
                max = 25
            }, -- min and max height of the columns
            width = {
                min = 20,
                max = 50
            }, -- min and max width of the columns
            spacing = 3, -- spacing between columns
            align = "center"
        },
        ignore_missing = false, -- enable this to hide mappings for which you didn't specify a label
        hidden = {"<silent>", "<cmd>", "<Cmd>", "<CR>", "^:", "^ ", "^call ", "^lua "}, -- hide mapping boilerplate
        show_help = true, -- show help message on the command line when the popup is visible
        show_keys = true,
        triggers = "auto", -- automatically setup triggers
        triggers_nowait = { -- marks
        "`", "'", "g`", "g'", -- registers
        '"', "<c-r>", -- spelling
        "z="},
        triggers_blacklist = {
            -- list of mode / prefixes that should never be hooked by WhichKey
            -- this is mostly relevant for key maps that start with a native binding
            -- most people should not need to change this
            i = {"j", "k"},
            v = {"j", "k"}
        },
        -- disable the WhichKey popup for certain buf types and file types.
        -- Disabled by default for Telescope
        disable = {
            buftypes = {},
            filetypes = {}
        }
    },
    opts = {
        mode = "n", -- NORMAL mode
        prefix = "<leader>",
        buffer = nil, -- Global mappings. Specify a buffer number for buffer local mappings
        silent = true, -- use `silent` when creating keymaps
        noremap = true, -- use `noremap` when creating keymaps
        nowait = true -- use `nowait` when creating keymaps
    },
    vopts = {
        mode = "v", -- VISUAL mode
        prefix = "<leader>",
        buffer = nil, -- Global mappings. Specify a buffer number for buffer local mappings
        silent = true, -- use `silent` when creating keymaps
        noremap = true, -- use `noremap` when creating keymaps
        nowait = true -- use `nowait` when creating keymaps
    },
    vmappings = {},
    mappings = {

        ["n"] = {"<cmd>NnnPicker<cr>", "nnn"},
        ["N"] = {"<cmd>NnnPicker %:p:h<cr>", "nnn (current buffer dir)"}
    }

}

whichkey.setup(config)
whichkey.register(config.mappings, config.opts)
whichkey.register(config.vmappings, config.vopts)
