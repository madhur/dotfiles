local status_ok, bufferline = pcall(require, "bufferline")
if not status_ok then
  return
end



bufferline.setup {
        options = {
            mode = "buffers", -- set to "tabs" to only show tabpages instead
            style_preset = bufferline.style_preset.default, -- or bufferline.style_preset.minimal,
            themable = true, -- allows highlight groups to be overriden i.e. sets highlights as default
            numbers = "none" ,
            close_command = "bdelete! %d",       -- can be a string | function, | false see "Mouse actions"
            right_mouse_command = "bdelete! %d", -- can be a string | function | false, see "Mouse actions"
            left_mouse_command = "buffer %d",    -- can be a string | function, | false see "Mouse actions"
            middle_mouse_command = nil,          -- can be a string | function, | false see "Mouse actions"
            indicator = {
                icon = '▎', -- this should be omitted if indicator style is not 'icon'
                style = 'icon',
            },
            --buffer_close_icon = '   ',
            modified_icon = '●',
            buffer_close_icon = '',
            close_icon = '',
            left_trunc_marker = '',
            right_trunc_marker = '',
            --- name_formatter can be used to change the buffer's label in the bufferline.
            --- Please note some names can/will break the
            --- bufferline so use this at your discretion knowing that it has
            --- some limitations that will *NOT* be fixed.
            max_name_length = 30,
            max_prefix_length = 30, -- prefix used when a buffer is de-duplicated
            truncate_names = true, -- whether or not tab names should be truncated
            tab_size = 21,
            diagnostics = "false",
            diagnostics_update_in_insert = false,
            -- The diagnostics indicator can be set to nil to keep the buffer name highlight but delete the highlighting
            -- NOTE: this will be called a lot so don't do any heavy processing here
            offsets = {
                {
                    filetype = "NvimTree",
                    text = "" ,
                    text_align = "left",
                    separator = true
                }
            },
            color_icons = true , -- whether or not to add the filetype icon highlights
            get_element_icon = function(element)
              -- element consists of {filetype: string, path: string, extension: string, directory: string}
              -- This can be used to change how bufferline fetches the icon
              -- for an element e.g. a buffer or a tab.
              -- e.g.
              local icon, hl = require('nvim-web-devicons').get_icon_by_filetype(element.filetype, { default = false })
              return icon, hl
              -- or
            end,
            show_buffer_icons = true, -- disable filetype icons for buffers
            show_buffer_close_icons = true,
            show_close_icon = true ,
            show_tab_indicators = true,
            show_duplicate_prefix = true, -- whether to show duplicate buffer prefix
            persist_buffer_sort = true, -- whether or not custom sorted buffers should persist
            move_wraps_at_ends = false, -- whether or not the move command "wraps" at the first or last position
            -- can also be a table containing 2 custom separators
            -- [focused and unfocused]. eg: { '|', '|' }
            separator_style =  "thin" ,
            enforce_regular_tabs = true,
            always_show_bufferline = true,
            hover = {
                enabled = true,
                delay = 200,
                reveal = {'close'}
            },
            sort_by = 'insert_after_current'
        }
    }
