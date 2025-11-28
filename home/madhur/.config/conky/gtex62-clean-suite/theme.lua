--[[
  ~/.config/conky/theme.lua
  Centralized Conky theme configuration

  This table is required by all Conky widgets via:
      local theme = dofile(os.getenv("HOME") .. "/.config/conky/theme.lua")

  It provides:
    • Typography and base colors
    • Shared layout helpers (graph sizes, column positions, char width)
    • Notes + calendar sizing and placement
    • Rainmeter-style system info options (slash bars, separators)
    • Weather / horizon layout used by lua/owm.lua
    • Planet + sun/moon marker styles

  Most widgets should only need to read values from here; layout tweaks
  happen in this file rather than in each individual .conky.conf.
]]

return {
  ----------------------------------------------------------------
  -- Typography & basic colors
  ----------------------------------------------------------------
  font              = 'DejaVu Sans Mono:size=10',
  default_color     = 'FFFFFF',
  color1            = 'A0A0A0', -- generic label color
  color_ok          = '00FF00',
  color_warn        = 'FFA500',
  color_err         = 'FF5555',

  -- Specialized fonts
  font_time         = 'DejaVu Sans Mono:size=22', -- main clock line
  font_date         = 'DejaVu Sans Mono:size=12', -- date line
  font_gmt          = 'DejaVu Sans Mono:size=10', -- GMT line font

  -- Approx monospace char width in px at the base font size
  -- (used as a rough helper for layout only, not pixel-perfect)
  char_px           = 7,

  ----------------------------------------------------------------
  -- Layout helpers (generic)
  ----------------------------------------------------------------
  goto_col          = 185, -- default X column for text after labels
  graph_height      = 80,
  graph_width       = 370,

  ----------------------------------------------------------------
  -- Notes-specific (optional widget)
  ----------------------------------------------------------------
  font_notes        = 'DejaVu Sans Mono:size=9',
  notes_wrap        = 39, -- wrap column in characters
  notes_lines       = 90, -- maximum lines to show
  notes_line_px     = 14, -- vertical spacing per line (px)

  ----------------------------------------------------------------
  -- Calendar
  ----------------------------------------------------------------
  week_start        = 'SU', -- calendar week start: 'SU' or 'MO'
  font_cal_title    = 'DejaVu Sans Mono:style=Bold:size=10',

  -- Sizes / spacing (px)
  cal_cell_w        = 44,
  cal_cell_h        = 26,
  cal_col_gap       = 2,
  cal_row_gap       = 3,
  cal_border_lw     = 0, -- 0 = no cell borders
  cal_title_size    = 18,
  cal_weekday_size  = 12,
  cal_day_size      = 16,
  cal_title_h       = 30,
  cal_title_gap     = 8, -- extra gap between title and weekdays

  -- Colors
  calendar_hilite   = 'FFD54A', -- highlight color for today / selected
  cal_weekend_color = '777777', -- gray for Sat/Sun labels

  -- Placement / tiling (used by calendar.lua for multi-month layouts)
  cal_origin_x      = 0,
  cal_origin_y      = 0,
  cal_gap_x         = 50, -- horizontal gap between month blocks
  cal_gap_y         = 30,   -- vertical gap between month blocks

  ----------------------------------------------------------------
  -- Rainmeter-style sys-info additions
  ----------------------------------------------------------------
  pipe_col          = 260, -- first vertical separator column
  pipe2_col         = 320, -- optional second separator column
  indent_spaces     = 4,   -- text indent after pipes

  -- Fixed slash bars (e.g., CPU/RAM usage)
  slash_count       = 20,
  bar_fill_color    = 'FFD54A',
  bar_empty_color   = '5A5A5A',
  bar_char          = '/',

  -- Network graph colors (for up/down)
  net_up_color      = 'FFB000',
  net_down_color    = '00D7FF',

  -- Separator line style
  sep_char          = '-',
  sep_count         = 50,

  ----------------------------------------------------------------
  -- Refresh cadence for execpi-driven bits
  ----------------------------------------------------------------
  refresh_sec       = 5, -- seconds between script-driven updates

  ----------------------------------------------------------------
  -- Horizon / cardinal labels (used by owm.lua)
  ----------------------------------------------------------------
  horizon_labels    = {
    pt    = 12,
    color = { 1, 1, 1, 1 }, -- RGBA
    dy    = 18,             -- vertical offset below the arc
    lx    = 0,              -- fine x offset for "West"
    cx    = 0,              -- fine x offset for "South"/"North"
    rx    = 0,              -- fine x offset for "East"
  },

  ----------------------------------------------------------------
  -- Weather / horizon layout (used by lua/owm.lua)
  ----------------------------------------------------------------
  weather           = {
    -- Weather icon anchor and size.
    -- x,y controls icon and the nearby text group (city, temp, humidity).
    icon            = { x = 200, y = 74, w = 80 },

    -- Arc geometry is *relative* to icon center:
    --   cx = icon.x + icon.w/2 + dx
    --   cy = icon.y + icon.w/2 + dy
    -- Angles are degrees in screen coordinates; direction follows owm.lua.
    arc             = { dx = 160, dy = 90, r = 170, start = 180, ["end"] = 0 },

    -- Arc stroke colors (RGBA, 0.0–1.0 range)
    day_color       = { 0.65, 0.65, 0.65, 1.0 }, -- gray for day
    night_color     = { 0.45, 0.60, 0.95, 1.0 }, -- light blue for night

    -- Sunrise / sunset time labels at arc ends
    sun_time_labels = {
      pt        = 14,
      color     = { 0.63, 0.63, 0.63, 1.0 },
      dy        = 34, -- vertical offset below the arc (defaults in code to horizon_labels.dy + 14)
      lx_offset = 0,  -- fine left x tweak
      rx_offset = 0,  -- fine right x tweak
    },

    -- METAR block (aviation weather)
    metar           = {
      enabled   = true,   -- turn METAR on/off
      station   = "KMEM", -- default ICAO
      wrap_col  = 40,
      pad_cols  = 16,
      max_lines = 5, -- limit METAR to this many lines (ellipsis on last if truncated)
    },

    -- TAF block (Terminal Aerodrome Forecast)
    taf             = {
      enabled     = true,   -- turn TAF on/off
      station     = "KMEM", -- ICAO (can be different than METAR)
      wrap_col    = 60,
      pad_cols    = 16,
      max_lines   = 4,
      indent_cols = 5, -- extra spaces for every line after the first
    },

    -- SIGMET / AIRMET advisories
    advisories      = {
      enabled   = false,  -- turn SIGMET/AIRMET on/off
      station   = "KMEM", -- center point (used by airsig_filter.sh)
      radius_nm = 300,    -- search radius in nautical miles
      wrap_col  = 60,     -- line width for wrapping
      pad_cols  = 16,     -- indent to match METAR/TAF
      max_lines = 5,      -- cap lines shown (ellipsis on last if truncated)
    },

    -- 5-day forecast layout (tile strip under the main widget)
    forecast        = {
      origin = { x = 174, y = 265 }, -- top-left of the strip (under main widget)
      tiles  = 5,                    -- number of days to show (today..today+4)
      gap    = 30,                   -- horizontal gap between tiles

      tile   = { w = 64, h = 110 },  -- tile footprint for layout

      -- Date label near top of each tile
      date   = {
        pt    = 14,
        dy    = 0,
        color = { 0.85, 0.85, 0.85, 1.0 },
      },

      -- Forecast icon position/size within each tile
      icon   = {
        size = 34,
        dy   = 46,
      },

      -- High / low temps per tile
      temps  = {
        pt       = 22,
        dy       = 98,                        -- vertical position of temps
        color_hi = { 1.00, 1.00, 1.00, 1.0 }, -- high temp color
        color_lo = { 0.70, 0.70, 0.70, 1.0 }, -- low temp color
      },

      -- Optional: per-strip opacity multiplier (0.0..1.0)
      alpha  = 1.0,
    },

    -- Optional: OpenWeather cache path override (normally set in owm.lua)
    -- cache   = {
    --   owm_current = (os.getenv("HOME") or "") .. "/.cache/conky/owm_current.json",
    --   owm_daily   = (os.getenv("HOME") or "") .. "/.cache/conky/owm_daily.json",
    -- },
  },

  ----------------------------------------------------------------
  -- Planet + horizon marker styles
  -- Used by owm.lua to draw planets + sun/moon markers on the arc.
  ----------------------------------------------------------------
  planets           = {
    -- Clip planets to the visible arc span
    clip             = true,

    -- Radial offset for Mercury (pixels from arc radius); 0 = sit on the arc
    mercury_arc_dr   = 0,

    -- Experimental geometry tuning knobs (currently unused in owm.lua):
    edge_relief_frac = 0.00, -- inward slide near ends; increase for more relief
    north_span_frac  = 0.00, -- additional arc shaping for northern hemisphere
    alt_lift_per_deg = 0.0,  -- pixels per degree of altitude; higher = more lift

    -- Per-planet style (circle radius + RGBA color)
    style            = {
      VENUS   = { r = 12, color = { 1.00, 0.95, 0.70, 1.00 } }, -- cream-yellow, bright
      MARS    = { r = 15, color = { 0.95, 0.45, 0.20, 1.00 } }, -- red-orange
      JUPITER = { r = 13, color = { 0.90, 0.82, 0.65, 1.00 } }, -- pale tan
      SATURN  = { r = 12, color = { 0.85, 0.75, 0.50, 1.00 } }, -- pale gold
      MERCURY = { r = 9, color = { 0.78, 0.80, 0.86, 1.00 } },  -- gray-silver
    },
  },

  weather_markers   = {
    -- Hollow sun marker on the arc
    sun = {
      diameter = 36,                         -- outer diameter in pixels
      stroke   = 10.0,                       -- line width in pixels
      color    = { 1.00, 0.78, 0.10, 1.00 }, -- RGBA (orange/yellow)
    },

    -- Hollow moon marker on the arc
    moon = {
      diameter = 26,
      stroke   = 10.0,
      color    = { 0.75, 0.75, 0.80, 1.00 }, -- RGBA (grayish)
    },
  },
}
