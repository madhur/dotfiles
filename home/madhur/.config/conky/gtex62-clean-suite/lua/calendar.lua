---@diagnostic disable: lowercase-global

-- Pixel-perfect Conky calendar using builtin Lua-Cairo.
-- Needs: /usr/bin/conky (Lua bindings: Cairo), and theme.lua alongside.
-- Navigation: ~/.cache/conky/cal_offset.txt (set by cal_nav.sh below)

require("cairo")
require("cairo_xlib")

-- ------------ helpers ------------
local function hex_to_rgb(hex)
  hex = (hex or "FFFFFF"):gsub("#", "")
  if #hex < 6 then hex = "FFFFFF" end
  return tonumber(hex:sub(1, 2), 16) / 255,
      tonumber(hex:sub(3, 4), 16) / 255,
      tonumber(hex:sub(5, 6), 16) / 255
end

local function days_in_month(y, m)
  local nm, ny = m + 1, y
  if nm == 13 then nm, ny = 1, y + 1 end
  local t = os.time { year = ny, month = nm, day = 0 }
  return os.date("*t", t).day
end

-- Sunday = 0 .. Saturday = 6
local function weekday_su0(y, m, d)
  local w = os.date("*t", os.time { year = y, month = m, day = d }).wday -- 1=Sun
  return w - 1
end

local function build_weeks(y, m, week_start_su)
  local dim = days_in_month(y, m)
  local first_col = weekday_su0(y, m, 1)                        -- 0..6, Sun=0
  if not week_start_su then first_col = (first_col + 6) % 7 end -- Monday start
  local weeks, row = {}, {}
  for _ = 1, first_col do row[#row + 1] = 0 end
  for d = 1, dim do
    row[#row + 1] = d
    if #row == 7 then
      weeks[#weeks + 1] = row; row = {}
    end
  end
  if #row > 0 then
    while #row < 7 do row[#row + 1] = 0 end; weeks[#weeks + 1] = row
  end
  return weeks
end

local function draw_text_center(cr, cx, cy, text, family, size, r, g, b, a)
  cairo_select_font_face(cr, family, CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
  cairo_set_font_size(cr, size)
  cairo_set_source_rgba(cr, r, g, b, a)
  local te = cairo_text_extents_t:create()
  cairo_text_extents(cr, text, te)
  local x = cx - (te.width / 2 + te.x_bearing)
  local y = cy - (te.height / 2 + te.y_bearing)
  x = math.floor(x + 0.5); y = math.floor(y + 0.5)
  cairo_move_to(cr, x, y); cairo_show_text(cr, text)
end

-- horizontally centered, fixed baseline Y (prevents month-to-month “jump”)
function draw_text_center_baseline(cr, cx, y, text, family, size, r, g, b, a)
  cairo_select_font_face(cr, family, CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
  cairo_set_font_size(cr, size)
  cairo_set_source_rgba(cr, r, g, b, a)
  local te = cairo_text_extents_t:create()
  cairo_text_extents(cr, text, te)
  local xx = math.floor((cx - (te.width / 2 + te.x_bearing)) + 0.5)
  local yy = math.floor(y + 0.5)
  cairo_move_to(cr, xx, yy); cairo_show_text(cr, text)
end

-- ------------ main draw hook ------------
function conky_draw_calendar()
  if conky_window == nil then return end
  local theme          = dofile((os.getenv("HOME") or "") .. "/.config/conky/gtex62-clean-suite/theme.lua")

  -- Theme knobs (with defaults)
  local week_start     = (theme.week_start or "SU"):upper()
  local week_start_su  = (week_start ~= "MO")
  local font_main_full = theme.font or "DejaVu Sans Mono:size=10"
  local font_main      = font_main_full:match("^[^:]+") or "DejaVu Sans Mono"
  local font_bold_full = theme.font_cal_title or font_main_full
  local font_bold      = font_bold_full:match("^[^:]+") or font_main

  -- Pixel geometry
  local cell_w         = theme.cal_cell_w or 44
  local cell_h         = theme.cal_cell_h or 26
  local col_gap        = theme.cal_col_gap or 2
  local row_gap        = theme.cal_row_gap or 3
  local border_w       = theme.cal_border_lw or 1

  local title_size     = theme.cal_title_size or 18
  local weekday_size   = theme.cal_weekday_size or 12
  local day_size       = theme.cal_day_size or 16

  local grid_hex       = theme.cal_grid_color or "5A5A5A"
  local text_hex       = theme.default_color or "FFFFFF"
  local label_hex      = theme.color1 or "A0A0A0"
  local hil_hex        = theme.calendar_hilite or theme.color_ok or "FFD54A"
  local weekend_hex    = theme.cal_weekend_color or "777777" -- darker gray by default

  local origin_x       = theme.cal_origin_x or 0
  local origin_y       = theme.cal_origin_y or 0

  local title_h        = theme.cal_title_h or (title_size + 12)
  local title_gap      = theme.cal_title_gap or 6 -- extra space under title
  local header_h       = theme.cal_header_h or (weekday_size + 6)

  local cols, max_rows = 7, 6
  local grid_w         = cols * cell_w + (cols - 1) * col_gap
  local grid_h         = max_rows * cell_h + (max_rows - 1) * row_gap
  local total_w        = grid_w

  local gr, gg, gb     = hex_to_rgb(grid_hex)
  local tr, tg, tb     = hex_to_rgb(text_hex)
  local lr, lg, lb     = hex_to_rgb(label_hex)
  local rr, rg, rb     = hex_to_rgb(hil_hex)
  local wr, wg, wb     = hex_to_rgb(weekend_hex)

  -- Cairo context
  local cs             = cairo_xlib_surface_create(conky_window.display, conky_window.drawable,
    conky_window.visual, conky_window.width, conky_window.height)
  local cr             = cairo_create(cs)

  -- Month data + navigation offset
  local now            = os.date("*t")
  local offset         = 0
  do
    local f = io.open(os.getenv("HOME") .. "/.cache/conky/cal_offset.txt", "r")
    if f then
      offset = tonumber(f:read("*l")) or 0; f:close()
    end
  end
  local vy, vm = now.year, now.month + offset
  while vm > 12 do
    vm = vm - 12; vy = vy + 1
  end
  while vm < 1 do
    vm = vm + 12; vy = vy - 1
  end

  local year, month = vy, vm
  local title_str   = os.date("%B %Y", os.time { year = year, month = month, day = 1 })
  local weeks       = build_weeks(year, month, week_start_su)
  local today_day   = (year == now.year and month == now.month) and now.day or -1

  -- Title (centered, fixed baseline to avoid month-to-month wiggle)
  draw_text_center_baseline(cr, origin_x + total_w / 2, origin_y + title_h - 4,
    "< <<  " .. title_str .. "  >> >", font_bold, title_size, tr, tg, tb, 1)

  -- Weekday header (at fixed integer rows)
  local labels       = (week_start_su and { "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" }
    or { "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su" })
  local header_y     = math.floor((origin_y + title_h + title_gap) + 0.5)
  local cell_y_start = math.floor(header_y + header_h + 0.5)
  for c = 1, cols do
    local x  = origin_x + (c - 1) * (cell_w + col_gap)
    local cx = x + cell_w / 2
    local cy = math.floor(header_y + header_h / 2 + 0.5)
    draw_text_center(cr, cx, cy, labels[c], font_main, weekday_size, lr, lg, lb, 1)
  end

  -- Grid + numbers (always 6 rows to avoid layout shift)
  for r = 1, 6 do
    local row = weeks[r] or { 0, 0, 0, 0, 0, 0, 0 }
    for c = 1, cols do
      local d = row[c]
      local x = origin_x + (c - 1) * (cell_w + col_gap)
      local y = cell_y_start + (r - 1) * (cell_h + row_gap)

      if border_w > 0 then
        cairo_set_line_width(cr, border_w)
        cairo_set_source_rgba(cr, gr, gg, gb, 0.55)
        cairo_rectangle(cr, x + border_w / 2, y + border_w / 2, cell_w - border_w, cell_h - border_w)
        cairo_stroke(cr)
      end

      if d ~= 0 then
        local cx = x + cell_w / 2
        local cy = math.floor(y + cell_h / 2 + 0.5)

        -- weekend-aware color
        local is_weekend = (week_start_su and (c == 1 or c == 7)) or (not week_start_su and (c == 6 or c == 7))
        local nr, ng, nb = (is_weekend and wr or tr), (is_weekend and wg or tg), (is_weekend and wb or tb)
        if d == today_day then nr, ng, nb = rr, rg, rb end -- today's text = highlight color

        draw_text_center(cr, cx, cy, tostring(d), font_main, day_size, nr, ng, nb, 1)
      end
    end
  end

  cairo_destroy(cr)
  cairo_surface_destroy(cs)
end
