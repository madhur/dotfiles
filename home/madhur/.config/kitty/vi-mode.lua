local api = vim.api
local orig_buf = api.nvim_get_current_buf()
local term_buf = api.nvim_create_buf(false, true)
api.nvim_set_current_buf(term_buf)
vim.bo.scrollback = 100000
local term_chan = api.nvim_open_term(0, {})
api.nvim_chan_send(term_chan, table.concat(api.nvim_buf_get_lines(orig_buf, 0, -1, true), "\r\n"))
vim.fn.chanclose(term_chan)
api.nvim_buf_set_lines(orig_buf, 0, -1, true, api.nvim_buf_get_lines(term_buf, 0, -1, true))
api.nvim_set_current_buf(orig_buf)
api.nvim_buf_delete(term_buf, { force = true })
vim.bo.modified = false
api.nvim_win_set_cursor(0, {api.nvim_buf_line_count(0), 0})
