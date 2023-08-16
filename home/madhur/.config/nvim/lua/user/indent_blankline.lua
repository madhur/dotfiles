local status_ok, ib = pcall(require, "indent_blankline")
if not status_ok then
  vim.notify("indent_blankline not found")
  return
end


ib.setup {
    -- for example, context is off by default, use this to turn it on
    show_current_context = true,
    show_current_context_start = true,
}

--
-- vim.cmd [[highlight IndentBlanklineIndent1 guibg=#1e229f gui=nocombine]]
-- vim.cmd [[highlight IndentBlanklineIndent2 guibg=#1e2220 gui=nocombine]]
--
-- ib.setup {
--     char = "",
--     char_highlight_list = {
--         "IndentBlanklineIndent1",
--         "IndentBlanklineIndent2",
--     },
--     space_char_highlight_list = {
--         "IndentBlanklineIndent1",
--         "IndentBlanklineIndent2",
--     },
--     show_trailing_blankline_indent = false,
-- }
