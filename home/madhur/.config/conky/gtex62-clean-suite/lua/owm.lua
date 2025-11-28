--[[
  ~/.config/conky/gtex62-clean-suite/lua/owm.lua
  Unified OpenWeather + horizon arc + planets + aviation weather

  Overview
  --------
  This module is the "weather brain" for the Conky suite. It handles:
    • Loading layout + style from ~/.config/conky/gtex62-clean-suite/theme.lua (THEME.weather.*)
    • Reading OpenWeather current + forecast JSON caches via jq
    • Drawing a horizon arc with:
        - East / South|North / West labels
        - Sun marker (time-mapped along the arc)
        - Moon marker (time-mapped from moonrise → moonset)
        - Visible planets (Venus, Mars, Jupiter, Saturn, Mercury)
    • Drawing a 5-tile 5-day forecast strip (date, icon, hi/lo)
    • Drawing sunrise/sunset time labels at the arc ends
    • Aviation block: METAR, TAF, and SIGMET/AIRMET advisories

  External files / scripts
  ------------------------
    • Theme config:
        ~/.config/conky/gtex62-clean-suite/theme.lua
          - THEME.weather.icon.*
          - THEME.weather.arc.*
          - THEME.weather.planets.*
          - THEME.weather.forecast.*
          - THEME.weather.sun_time_labels.*
          - THEME.weather.metar.*, .taf.*, .advisories.*
    • OpenWeather caches (JSON, created by your fetch script):
        ~/.cache/conky/owm_current.json
        ~/.cache/conky/owm_daily.json      -- or theme/weather overrides
    • Sky variables (planet positions, etc):
        ~/.cache/conky/sky.vars
    • Helper scripts:
        ~/.config/conky/gtex62-clean-suite/scripts/moon_times.sh
        ~/.config/conky/gtex62-clean-suite/scripts/owm_fc_5rows.sh
        ~/.config/conky/gtex62-clean-suite/scripts/metar_ob.sh
        ~/.config/conky/gtex62-clean-suite/scripts/taf_wrap.sh
        ~/.config/conky/gtex62-clean-suite/scripts/airsig_filter.sh

  Conky calls (lua_parse)
  -----------------------
    ${lua_parse owm city}                    → OpenWeather city name
    ${lua_parse owm desc}                    → Weather description
    ${lua_parse owm temp}                    → Temperature (rounded)
    ${lua_parse owm humidity}                → Relative humidity
    ${lua_parse owm sunrise}                 → Local sunrise HH:MM
    ${lua_parse owm sunset}                  → Local sunset HH:MM

    ${lua_parse owm draw_horizon}            → Horizon arc + labels + sun/moon + planets
    ${lua_parse owm sun_labels}              → Sunrise / sunset time labels at arc ends
    ${lua_parse owm debug_arc}               → Debug string (cx, cy, r, start, end)

    ${lua_parse owm draw_forecast_placeholder} → 5-day forecast tiles (dates, icons, temps)
    ${lua_parse metar}                       → METAR (wrapped)
    ${lua_parse taf}                         → TAF (cleaned + wrapped)
    ${lua_parse advisories}                  → SIGMET / AIRMET summary

  Notes
  -----
  • Layout and styling are driven almost entirely by theme.lua; owm.vars is
    only used for cache path overrides.
  • All heavy lifting (JSON parsing, METAR/TAF logic, etc.) is done outside
    Conky via jq + shell scripts; this Lua file focuses on drawing + formatting.
]]
--------------------------------------------------------------------------


-- =====================================================================
-- 1. Theme + config helpers
--    - HOME / THEME detection
--    - tget(): nested dotted lookup "a.b.c"
--    - owm.vars overrides for cache paths
-- =====================================================================

-- Load theme.lua once (prefer local THEME, fallback to global `theme`)
local HOME = os.getenv("HOME") or ""
local THEME = (function()
  local path = HOME .. "/.config/conky/gtex62-clean-suite/theme.lua"
  local ok, t = pcall(dofile, path)
  if ok and type(t) == "table" then return t end
  if type(theme) == "table" then return theme end -- some themes set global
  return {}
end)()

-- Safe nested lookup: "a.b.c" → theme[a][b][c], returns nil if missing
local function tget(root, dotted)
  local node = root
  for key in string.gmatch(dotted or "", "[^.]+") do
    if type(node) ~= "table" then return nil end
    node = node[key]
    if node == nil then return nil end
  end
  return node
end

---------------------------------------------------
-- Read config values (theme first, then owm.vars)
---------------------------------------------------
-- Optional overrides from ~/.config/conky/owm.vars
-- Only used for cache paths; all layout comes from theme.lua.

local VARS_FILE = HOME .. "/.config/conky/gtex62-clean-suite/widgets/owm.vars"

local function read_vars_raw(name)
  local f = io.open(VARS_FILE, "r")
  if not f then return nil end
  local txt = f:read("*a") or ""
  f:close()
  local pat = "%f[%w_]" .. name .. "%s*=%s*([^\r\n#]+)"
  local val = txt:match(pat)
  if not val then return nil end
  return (val:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Current-conditions cache (owm_current.json)
local function get_cache_path()
  -- theme first
  local p = tget(THEME, "weather.cache.owm_current")
  if type(p) == "string" and p ~= "" then return p end
  -- fallback to owm.vars if uncommented there
  local raw = read_vars_raw("OWM_CACHE")
  if raw and raw ~= "" then return raw end
  -- default
  return HOME .. "/.cache/conky/owm_current.json"
end

-- Daily / One Call cache path (for 5-day forecast tiles)
local function get_daily_cache_path()
  -- 1) theme override
  local p = tget(THEME, "weather.cache.owm_daily")
  if type(p) == "string" and p ~= "" then return p end

  -- 2) optional owm.vars override
  local raw = read_vars_raw("OWM_DAILY_CACHE")
  if raw and raw ~= "" then return raw end

  -- 3) default fallback
  return HOME .. "/.cache/conky/owm_daily.json"
end


-- Conky-callable: ${lua_parse theme <dotted.path>}
-- Example: ${lua_parse theme metar.wrap_col}
function conky_theme(path)
  -- 1) try THEME that owm.lua already loaded
  local v = tget(THEME, path)

  -- 2) fallback to global `theme` if needed, without changing variable types
  if v == nil and type(theme) == "table" then
    local cur = theme -- keep as table-typed
    local ok  = true
    for part in string.gmatch(path or "", "[^.]+") do
      if type(cur) ~= "table" then
        ok = false; break
      end
      local nxt = rawget(cur, part)
      if nxt == nil then
        ok = false; break
      end
      cur = nxt -- stays a table or value; we don't assign nil to 'cur'
    end
    if ok then v = cur end
  end

  return (v ~= nil) and tostring(v) or ""
end

-- Layout helpers pull ONLY from theme, with sensible defaults
local function icon_geom()
  local x = tonumber(tget(THEME, "weather.icon.x")) or 196
  local y = tonumber(tget(THEME, "weather.icon.y")) or 70
  local w = tonumber(tget(THEME, "weather.icon.w")) or 96
  return x, y, w
end

local function arc_geom()
  local dx   = tonumber(tget(THEME, "weather.arc.dx")) or 160
  local dy   = tonumber(tget(THEME, "weather.arc.dy")) or 100
  local r    = tonumber(tget(THEME, "weather.arc.r")) or 170
  local sdeg = tonumber(tget(THEME, "weather.arc.start")) or 180
  local edeg = tonumber(tget(THEME, "weather.arc.end")) or 0
  return dx, dy, r, sdeg, edeg
end

local function planets_opts()
  local clip = tget(THEME, "weather.planets.clip")
  if type(clip) ~= "boolean" then clip = true end
  local merc_dr = tonumber(tget(THEME, "weather.planets.mercury_arc_dr")) or 0
  return clip, merc_dr
end

----------------------------
-- JSON access via jq
----------------------------
-- Global path to current-conditions cache (used by read_field)
local CACHE_JSON = get_cache_path()

-- Return true if a file exists and is readable
local function file_exists(p)
  local f = io.open(p, "r"); if not f then return false end
  f:close(); return true
end

-- Read a single JSON value with jq. Returns a trimmed string or nil.
local function read_field(jq_path)
  if not (CACHE_JSON and file_exists(CACHE_JSON)) then return nil end
  local cmd = string.format([[jq -r '%s // empty' %q 2>/dev/null]], jq_path, CACHE_JSON)
  local p = io.popen(cmd, "r"); if not p then return nil end
  local out = (p:read("*a") or ""):gsub("%s+$", "")
  p:close()
  if out == "" then return nil end
  return out
end

----------------------------
-- Time formatting (24h)
----------------------------
-- Format a Unix timestamp as local "HH:MM" (24-hour)
local function fmt_hhmm(ts)
  local n = tonumber(ts); if not n then return "" end
  local s = os.date("%H:%M", n) -- 24-hour local time
  return (type(s) == "string") and s or ""
end



-- =====================================================================
-- 2. Horizon arc geometry
--    - arc is "locked" to the main icon position (from theme.weather.icon)
--    - helpers for angle normalization and visible span check
-- =====================================================================

-- Compute arc center (cx,cy) from icon geometry + theme.weather.arc.*
local function get_arc_geometry()
  local ix, iy, iw = icon_geom()
  local dx, dy, r, sdeg, edeg = arc_geom()
  local cx = ix + (iw / 2) + dx
  local cy = iy + (iw / 2) + dy
  return cx, cy, r, sdeg, edeg
end

-- Convert degrees → radians
local function deg2rad(d) return (math.pi / 180) * d end

-- Point on arc at angle "deg" (screen coords, y up)
local function pt_on_arc(cx, cy, r, deg)
  local th = deg2rad(deg)
  return (cx + r * math.cos(th)), (cy - r * math.sin(th))
end

-- Normalize angle to [0, 360)
local function norm_deg(d)
  d = d % 360; if d < 0 then d = d + 360 end; return d
end

-- Return true if theta_deg lies on the visible arc from start→end
local function on_visible_arc(theta_deg, sdeg, edeg)
  local t = norm_deg(theta_deg)
  local s = norm_deg(sdeg)
  local e = norm_deg(edeg)
  if s < e then s, e = e, s end
  return (t >= e) and (t <= s)
end



-- =====================================================================
-- 3. Conky dispatcher: ${lua_parse owm <key>}
--    Lightweight string API around the current-conditions cache.
-- =====================================================================
function conky_owm(key)
  if not key or key == "" then return "" end

  -- Simple string fields
  if key == "city" then return read_field(".name") or "" end
  if key == "desc" then return read_field(".weather[0].description") or "" end

  -- Numeric fields with formatting
  if key == "temp" then
    local t = tonumber(read_field(".main.temp") or ""); return t and string.format("%.0f", t) or ""
  end
  if key == "humidity" then return read_field(".main.humidity") or "" end
  if key == "wind" then return read_field(".wind.speed") or "" end

  -- Sunrise / sunset
  if key == "sunrise" then return fmt_hhmm(read_field(".sys.sunrise")) end
  if key == "sunset" then return fmt_hhmm(read_field(".sys.sunset")) end

  -- Drawing entrypoints
  if key == "draw_horizon" then return conky_owm_draw_horizon() or "" end
  if key == "sun_labels" then return conky_owm_sun_labels() or "" end

  if key == "draw_forecast_placeholder" then return conky_owm_draw_forecast_placeholder() or "" end

  -- if key == "draw_main_icon" then return conky_owm_draw_main_icon() or "" end

  -- Debug
  if key == "debug_arc" then
    local cx, cy, r, s, e = get_arc_geometry()
    return string.format("cx=%d cy=%d r=%d start=%d end=%d", cx, cy, r, s, e)
  end

  return ""
end

--------------------------
-- Cairo availability
--------------------------
local has_cairo = pcall(require, "cairo")



-- =====================================================================
-- 4. Drawing: horizon arc + direction labels + sun/moon + planets
--    Called via: ${lua_parse owm draw_horizon}
-- =====================================================================

-- 4.1 Arc stroke
function conky_owm_draw_horizon()
  if not has_cairo or not conky_window then return "" end

  local cs = cairo_xlib_surface_create(conky_window.display,
    conky_window.drawable,
    conky_window.visual,
    conky_window.width,
    conky_window.height)
  local cr = cairo_create(cs)

  -- >>> SANDBOX the whole draw <<<
  cairo_save(cr)     -- NEW: protect all state for this draw
  cairo_new_path(cr) -- NEW: start with a clean path

  local cx, cy, r, ARC_START, ARC_END = get_arc_geometry()

  -- Draw arc with day/night color from theme.lua
  cairo_save(cr)
  cairo_set_line_width(cr, 1.5)

  -- Determine day vs night from OpenWeather sunrise/sunset
  local sr_ts    = tonumber(read_field(".sys.sunrise") or "")
  local ss_ts    = tonumber(read_field(".sys.sunset") or "")
  local now      = os.time()

  local is_night = false
  if sr_ts and ss_ts then
    -- Night if we are before sunrise or after sunset
    is_night = (now < sr_ts) or (now > ss_ts)
  end

  -- Get arc color from THEME.weather.arc.day_color / night_color
  local arc_col_path = is_night
      and "weather.arc.night_color"
      or "weather.arc.day_color"

  local arc_col = tget(THEME, arc_col_path)

  -- Fallbacks if theme fields are missing or malformed
  if type(arc_col) ~= "table" or #arc_col < 4 then
    if is_night then
      arc_col = { 0.60, 0.80, 1.00, 1.0 } -- light blue
    else
      arc_col = { 0.65, 0.65, 0.65, 1.0 } -- original gray
    end
  end

  cairo_set_source_rgba(cr, arc_col[1], arc_col[2], arc_col[3], arc_col[4])
  cairo_arc(cr, cx, cy, r, deg2rad(ARC_START), deg2rad(ARC_END))
  cairo_stroke(cr)
  cairo_new_path(cr)
  cairo_restore(cr)



  -- 4.2 Cardinal horizon labels (East / South|North / West)
  do
    -- safe theme getter
    local function tm_get(path, default)
      if type(tget) == "function" and type(THEME) == "table" then
        local v = tget(THEME, path)
        if v ~= nil then return v end
      end
      local cur = theme
      if type(cur) ~= "table" then return default end
      for key in string.gmatch(path, "[^%.]+") do
        if type(cur) ~= "table" then return default end
        local nxt = rawget(cur, key)
        if nxt == nil then return default end
        cur = nxt
      end
      return cur
    end

    -- settings (override in theme.lua if you want)
    -- theme.horizon_labels = { pt = 14, color = {1,1,1,1}, dy = 18, lx = 0, cx = 0, rx = 0 }
    local hl_pt  = tonumber(tm_get("horizon_labels.pt", 14)) or 14
    local hl_col = tm_get("horizon_labels.color", { 1, 1, 1, 1 })
    if type(hl_col) ~= "table" then hl_col = { 1, 1, 1, 1 } end
    local hl_dy = tonumber(tm_get("horizon_labels.dy", 18)) or 18 -- vertical offset *below* the arc
    local hl_lx = tonumber(tm_get("horizon_labels.lx", 0)) or 0   -- fine x offsets
    local hl_cx = tonumber(tm_get("horizon_labels.cx", 0)) or 0
    local hl_rx = tonumber(tm_get("horizon_labels.rx", 0)) or 0

    -- helpers
    local function deg2rad(d) return d * math.pi / 180 end
    local function arc_point(cx0, cy0, r0, ang_deg)
      local a = deg2rad(ang_deg)
      return cx0 + r0 * math.cos(a), cy0 - r0 * math.sin(a) -- y up on screen
    end
    local function arc_mid(s, e)
      local span = (s - e) % 360
      if span == 0 then span = 360 end
      return (e + span / 2) % 360
    end

    -- detect hemisphere from latitude (OWM cache first, else theme override)
    local lat = tonumber(read_field and read_field(".coord.lat") or nil)
        or tonumber(read_field and read_field(".lat") or nil)
        or tonumber(tm_get("weather.lat", nil))
    local apex_label = (lat and lat < 0) and "North" or "South"

    -- label positions: left = ARC_START (West), right = ARC_END (East), center = arc midpoint (S/N)
    local lx, ly = arc_point(cx, cy, r, ARC_START)
    local rx, ry = arc_point(cx, cy, r, ARC_END)
    local mx, my = arc_point(cx, cy, r, arc_mid(ARC_START, ARC_END))

    -- push labels *below* the arc by dy, plus optional x tweaks
    ly = ly + hl_dy; ry = ry + hl_dy; my = my + hl_dy
    lx = lx + hl_lx; rx = rx + hl_rx; mx = mx + hl_cx

    -- draw labels (clear any prior path; center text at each anchor)
    cairo_save(cr)
    cairo_new_path(cr) -- prevent stray lines from previous shapes

    cairo_select_font_face(cr, "Sans", 0, 0)
    cairo_set_font_size(cr, hl_pt)
    cairo_set_source_rgba(cr, hl_col[1], hl_col[2], hl_col[3], hl_col[4])

    local ext = cairo_text_extents_t:create()

    -- West
    cairo_text_extents(cr, "West", ext)
    cairo_move_to(cr, lx - ext.width / 2, ly)
    cairo_text_path(cr, "West")
    cairo_fill(cr) -- fills & clears the text path

    -- South/North
    cairo_text_extents(cr, apex_label, ext)
    cairo_move_to(cr, mx - ext.width / 2, my)
    cairo_text_path(cr, apex_label)
    cairo_fill(cr)

    -- East
    cairo_text_extents(cr, "East", ext)
    cairo_move_to(cr, rx - ext.width / 2, ry)
    cairo_text_path(cr, "East")
    cairo_fill(cr)

    cairo_new_path(cr) -- ensure no residual path
    cairo_restore(cr)
  end
  -- ================================================================


  -- 4.3 Sun marker (time-mapped between sunrise/sunset)
  do
    cairo_save(cr)
    -- self-contained helpers
    local function _deg2rad_s(d) return d * math.pi / 180 end
    local function _pt_s(cx, cy, r, ang_deg)
      local a = _deg2rad_s(ang_deg)
      return cx + r * math.cos(a), cy - r * math.sin(a) -- match pt_on_arc()
    end
    local function _tm_get(path, default)
      if type(tget) == "function" and type(THEME) == "table" then
        local v = tget(THEME, path)
        if v ~= nil then return v end
      end
      local cur = theme
      if type(cur) ~= "table" then return default end
      for key in string.gmatch(path, "[^%.]+") do
        if type(cur) ~= "table" then return default end
        local nxt = rawget(cur, key)
        if nxt == nil then return default end
        cur = nxt
      end
      return cur
    end
    local function _clamp01(x)
      if x < 0 then return 0 elseif x > 1 then return 1 else return x end
    end
    local function _arc_span(start_deg, end_deg)
      local span = (start_deg - end_deg) % 360
      if span == 0 then span = 360 end
      return span
    end

    -- theme-driven style
    local sun_diam = tonumber(_tm_get("weather_markers.sun.diameter", 14)) or 14
    local sun_sw   = tonumber(_tm_get("weather_markers.sun.stroke", 2.0)) or 2.0
    local sun_col  = _tm_get("weather_markers.sun.color", { 1.00, 0.78, 0.10, 1.00 })
    if type(sun_col) ~= "table" then sun_col = { 1.00, 0.78, 0.10, 1.00 } end
    local sun_r  = sun_diam / 2

    -- get sunrise/sunset epoch seconds from OWM cache
    local sr_ts  = tonumber(read_field and read_field(".sys.sunrise") or nil)
    local ss_ts  = tonumber(read_field and read_field(".sys.sunset") or nil)
    local now    = os.time()
    local is_day = (sr_ts and ss_ts) and (now >= sr_ts and now <= ss_ts)

    -- compute progress across the day (for placement if visible)
    local theta_deg
    if sr_ts and ss_ts and ss_ts > sr_ts then
      local p    = _clamp01((now - sr_ts) / (ss_ts - sr_ts))
      local span = _arc_span(ARC_START, ARC_END) -- 0→right (sunrise), 1→left (sunset)
      theta_deg  = (ARC_END + p * span) % 360
    else
      -- fallback: midpoint if times missing; will be ignored if !is_day
      local span = _arc_span(ARC_START, ARC_END)
      theta_deg  = (ARC_END + 0.5 * span) % 360
    end

    -- draw the hollow sun only during daytime
    if is_day then
      local sx, sy = _pt_s(cx, cy, r, theta_deg)
      cairo_set_line_width(cr, sun_sw)
      cairo_set_source_rgba(cr, sun_col[1], sun_col[2], sun_col[3], sun_col[4])
      cairo_arc(cr, sx, sy, sun_r, 0, 2 * math.pi)
      cairo_stroke(cr)
      cairo_new_path(cr)
    end
  end
  -- ================================================================


  -- 4.4 Moon marker (time-mapped between moonrise/moonset)
  do
    cairo_save(cr)

    -- minimal helpers
    local function deg2rad(d) return d * math.pi / 180 end
    local function arc_span(start_deg, end_deg)
      local s = (start_deg - end_deg) % 360
      return (s == 0) and 360 or s
    end
    local function pt_on_arc_local(cx_, cy_, r_, ang_deg)
      local a = deg2rad(ang_deg)
      return cx_ + r_ * math.cos(a), cy_ - r_ * math.sin(a)
    end

    -- Local safe theme getter for this block only (avoids global side effects)
    local function _tm_get(path, default)
      if type(tget) == "function" and type(THEME) == "table" then
        local v = tget(THEME, path)
        if v ~= nil then return v end
      end
      local cur = theme
      if type(cur) ~= "table" then return default end
      for key in string.gmatch(path, "[^%.]+") do
        if type(cur) ~= "table" then return default end
        local nxt = rawget(cur, key)
        if nxt == nil then return default end
        cur = nxt
      end
      return cur
    end

    -- read moonrise/set via your script each tick (fast, tiny output)
    local function get_moon_times()
      local home = os.getenv("HOME") or ""
      local cmd  = string.format("%s/.config/conky/gtex62-clean-suite/scripts/moon_times.sh", home)
      local p    = io.popen(cmd, "r"); if not p then return nil, nil end
      local rise_ts, set_ts
      for line in p:lines() do
        local v = line:match("MOON_RISE_TS=(%d+)")
        if v then rise_ts = tonumber(v) end
        v = line:match("MOON_SET_TS=(%d+)")
        if v then set_ts = tonumber(v) end
      end
      p:close()
      return rise_ts, set_ts
    end

    local rise_ts, set_ts = get_moon_times()
    if not (rise_ts and set_ts) then
      cairo_restore(cr); goto moon_end
    end

    local now = os.time()
    if not (now >= rise_ts and now <= set_ts) then
      -- Moon below horizon: do not draw (no cue)
      cairo_restore(cr); goto moon_end
    end

    -- fraction of the way from moonrise (east/right) to moonset (west/left)
    local denom = math.max(1, set_ts - rise_ts)
    local p = (now - rise_ts) / denom
    if p < 0 then p = 0 elseif p > 1 then p = 1 end

    -- map p: 0 → ARC_END (East/right), 1 → ARC_START (West/left)
    local span      = arc_span(ARC_START, ARC_END)
    local theta     = (ARC_END + p * span) % 360

    -- theme driven style
    local moon_diam = tonumber(_tm_get("weather_markers.moon.diameter", 14)) or 28
    local moon_sw   = tonumber(_tm_get("weather_markers.moon.stroke", 2.0)) or 2.0
    local moon_col  = _tm_get("weather_markers.moon.color", { 0.75, 0.75, 0.80, 1.00 })

    -- draw the moon at time-mapped theta
    local mx, my    = pt_on_arc_local(cx, cy, r, theta)
    cairo_set_line_width(cr, moon_sw)
    cairo_set_source_rgba(cr, moon_col[1], moon_col[2], moon_col[3], moon_col[4])
    cairo_arc(cr, mx, my, moon_diam / 2, 0, 2 * math.pi)
    cairo_stroke(cr)
    cairo_new_path(cr)

    ::moon_end::
  end


  -- 4.5 Planet markers (Venus, Mars, Jupiter, Saturn, Mercury)

  -- Planet helpers (read radii and angles from ~/.cache/conky/sky.vars)
  -- Read order: PREFIX_THETA (deg) > PREFIX_AZ (deg, horizon-filtered)

  local function read_size(key, default_r)
    local f = io.open(HOME .. "/.cache/conky/sky.vars", "r"); if not f then return default_r end
    local s = f:read("*a") or ""; f:close()
    local v = s:match("^%s*" .. key .. "%s*=%s*([%-0-9%.]+)")
    return v and tonumber(v) or default_r
  end

  -- Return nil if the key is not present (so AZ can take over)
  local function read_theta(key, def)
    local f = io.open(HOME .. "/.cache/conky/sky.vars", "r"); if not f then return def end
    local s = f:read("*a") or ""; f:close()
    local m = s:match("^%s*" .. key .. "%s*=%s*([%-0-9%.]+)")
    return m and tonumber(m) or nil
  end

  -- Read a numeric key from sky.vars with "last occurrence wins"
  local function read_key_num(key)
    local f = io.open(HOME .. "/.cache/conky/sky.vars", "r"); if not f then return nil end
    local val = nil
    for line in f:lines() do
      local v = line:match("^%s*" .. key .. "%s*=%s*([%-0-9%.]+)%s*$")
      if v then val = tonumber(v) end
    end
    f:close()
    return val
  end

  -- Options for planets (clip to visible arc; Mercury default radial offset)
  local clip, mercury_dr_default = planets_opts()

  -- Prefer PREFIX_THETA; otherwise read PREFIX_AZ, hide if below horizon, and map to arc
  local function read_theta_or_az(prefix, def)
    -- 1) direct theta if present
    local t = read_theta(prefix .. "_THETA", nil)
    if t ~= nil then
      return t
    end

    -- 2) azimuth (last occurrence wins)
    local az = read_key_num(prefix .. "_AZ")
    if az == nil then
      return def
    end

    -- normalize 0..359
    az = (az % 360 + 360) % 360

    -- 3) visibility: only when above the horizon (E=90 .. W=270)
    if not (az > 90 and az < 270) then
      return nil -- below horizon → do not draw
    end

    -- 4) map azimuth (90..270) → arc angle between ARC_START..ARC_END
    --    p=0 at 90° (east/right), p=1 at 270° (west/left)
    local p = (az - 90) / 180.0
    if p < 0 then p = 0 elseif p > 1 then p = 1 end

    local span = (ARC_START - ARC_END) % 360
    if span == 0 then span = 360 end

    return (ARC_END + p * span) % 360
  end

  -- Draw a planet on the arc (with optional radial offset dr in pixels)
  local function draw_planet(theta_deg, radius, r_, g_, b_, a_, dr)
    if not theta_deg then return end -- hide if below horizon / no data
    if clip and (not on_visible_arc(theta_deg, ARC_START, ARC_END)) then return end
    local x, y = pt_on_arc(cx, cy, r + (dr or 0), theta_deg)
    cairo_arc(cr, x, y, radius, 0, 2 * math.pi)
    cairo_set_source_rgba(cr, r_, g_, b_, a_)
    cairo_fill(cr)
  end

  -- Theme-driven planet style: radius + RGBA color (checks weather.planets.style, then planets.style)
  local function planet_style(name, def_r, def_col)
    local function get_path(root, dotted)
      local node = root
      for key in string.gmatch(dotted, "[^%.]+") do
        if type(node) ~= "table" then return nil end
        node = rawget(node, key)
        if node == nil then return nil end
      end
      return node
    end

    local st = get_path(THEME, "weather.planets.style")
        or get_path(THEME, "planets.style")
        or (type(theme) == "table" and (get_path(theme, "weather.planets.style") or get_path(theme, "planets.style")))
        or nil

    local r, col = def_r, def_col
    local entry = (type(st) == "table") and st[name] or nil
    if type(entry) == "table" then
      if type(entry.r) == "number" then r = entry.r end
      if type(entry.color) == "table" then col = entry.color end
    end
    return r, col
  end

  -- Planets (colors match your earlier choices)
  do
    local rV, cV = planet_style("VENUS", read_size("VENUS_R", 9), { 1.00, 0.90, 0.50, 1.0 })
    draw_planet(read_theta_or_az("VENUS", 110), rV, cV[1], cV[2], cV[3], cV[4], 0)

    local rM, cM = planet_style("MARS", read_size("MARS_R", 6), { 0.95, 0.35, 0.25, 1.0 })
    draw_planet(read_theta_or_az("MARS", 130), rM, cM[1], cM[2], cM[3], cM[4], 0)

    local rJ, cJ = planet_style("JUPITER", read_size("JUPITER_R", 8), { 0.85, 0.82, 0.62, 1.0 })
    draw_planet(read_theta_or_az("JUPITER", 60), rJ, cJ[1], cJ[2], cJ[3], cJ[4], 0)

    local rS, cS = planet_style("SATURN", read_size("SATURN_R", 7), { 0.78, 0.75, 0.58, 1.0 })
    draw_planet(read_theta_or_az("SATURN", 40), rS, cS[1], cS[2], cS[3], cS[4], 0)

    local rMe, cMe = planet_style("MERCURY", read_size("MERCURY_R", 5), { 0.75, 0.78, 0.82, 1.0 })
    draw_planet(read_theta_or_az("MERCURY", 20), rMe, cMe[1], cMe[2], cMe[3], cMe[4], 0)
  end


  -- close horizon draw
  cairo_restore(cr)
  cairo_destroy(cr)
  cairo_surface_destroy(cs)
  return ""
end

-- (End of planet helpers/draws)  -- next section: Draw sunrise/sunset labels at arc ends


-- --------------------------------------------------
-- read_forecast_5()
--   Build up to 5 forecast rows:
--     { ts=<unix>, date_str="Nov Sun", hi=72, lo=58, icon="10d" }
--   Order: today (index 1) → today+4
--   Data precedence:
--     1) Helper script owm_fc_5rows.sh, if present
--     2) One Call .daily array in the forecast JSON
--     3) 3-hour .list array aggregated into days
-- --------------------------------------------------
local function read_forecast_5()
  local result = {}

  -- helper: pick forecast cache path
  local function fc_path()
    if type(get_daily_cache_path) == "function" then
      return get_daily_cache_path()
    end
    local HOME = os.getenv("HOME") or ""
    return HOME .. "/.cache/conky/owm_forecast.json"
  end

  -- helper: coerce icon to day variant (…d)
  local function day_icon(code)
    if type(code) ~= "string" or code == "" then return "" end
    -- codes like 01d/01n, 02d/02n, etc.
    return (code:gsub("n$", "d"))
  end

  -- 0) Prefer helper script output (idx, dt, hi, lo, code)
  do
    local HOME   = os.getenv("HOME") or ""
    local script = HOME .. "/.config/conky/gtex62-clean-suite/scripts/owm_fc_5rows.sh"
    local json   = fc_path()
    local f      = io.open(script, "r")
    if f then
      f:close()
      local p = io.popen(string.format("%q %q", script, json), "r")
      if p then
        for line in p:lines() do
          local _idx, s_dt, s_hi, s_lo, code =
              line:match("^(%d+)%s+(%d+)%s+([%-]?%d+)%s+([%-]?%d+)%s+(%S+)$")
          if s_dt and s_hi and s_lo and code then
            local ts = tonumber(s_dt) or 0
            local hi = tonumber(s_hi) or 0
            local lo = tonumber(s_lo) or 0
            result[#result + 1] = {
              ts       = ts,
              date_str = string.format("%s %s", os.date("%b", ts), os.date("%a", ts)),
              hi       = hi,
              lo       = lo,
              icon     = day_icon(code),
            }
          end
        end
        p:close()
        if #result >= 1 then
          -- ensure only first 5 rows (today→+4)
          while #result > 5 do table.remove(result) end
          return result
        end
      end
    end
  end

  -- 1) One Call daily (null-safe): take today→+4 from .daily
  do
    local J = fc_path()
    -- Null-safe jq: if .daily not array → []
    local cmd = string.format(
      [[jq -r '( ( .daily? // [] )[:5] ) | to_entries[] | [ .value.dt, ( .value.temp.max // .value.temp.day // 0 ), ( .value.temp.min // .value.temp.night // 0 ), ( .value.weather[0].icon // "" ) ] | @tsv' %q 2>/dev/null]],
      J
    )
    local p = io.popen(cmd, "r")
    if p then
      for line in p:lines() do
        local s_dt, s_hi, s_lo, code = line:match("^([^\t]+)\t([^\t]+)\t([^\t]+)\t(.+)$")
        local ts = tonumber(s_dt or "")
        local hi = tonumber(s_hi or "")
        local lo = tonumber(s_lo or "")
        if ts and ts > 0 then
          result[#result + 1] = {
            ts       = ts,
            date_str = string.format("%s %s", os.date("%b", ts), os.date("%a", ts)),
            hi       = math.floor((hi or 0) + 0.5),
            lo       = math.floor((lo or 0) + 0.5),
            icon     = day_icon(code or ""),
          }
        end
      end
      p:close()
      if #result >= 1 then
        while #result > 5 do table.remove(result) end
        return result
      end
    end
  end

  -- 2) Fallback: 3-hour forecast .list (null-safe), aggregate to days
  do
    local J = fc_path()
    -- Null-safe: (.list // []) to avoid “iterate over null”
    local cmd = string.format(
      [[jq -r '( .list // [] )[] | [ .dt, ( .main.temp_max // .main.temp // 0 ), ( .main.temp_min // .main.temp // 0 ), ( .weather[0].icon // "" ) ] | @tsv' %q 2>/dev/null]],
      J
    )
    local p = io.popen(cmd, "r"); if not p then return result end

    local Y = tonumber(os.date("%Y")) or 0
    local M = tonumber(os.date("%m")) or 0
    local D = tonumber(os.date("%d")) or 0
    local Yi = math.floor(Y) or 0
    local Mi = math.floor(M) or 0
    local Di = math.floor(D) or 0
    local noon_today = os.time { year = Yi, month = Mi, day = Di, hour = 12, min = 0, sec = 0 }


    local buckets, order = {}, {}
    for line in p:lines() do
      local s_dt, s_hi, s_lo, code = line:match("^([^\t]+)\t([^\t]+)\t([^\t]+)\t(.+)$")
      local dt = tonumber(s_dt or "")
      local hi = tonumber(s_hi or "")
      local lo = tonumber(s_lo or "")
      if dt and dt > 0 then
        local key = os.date("%Y-%m-%d", dt)
        local b = buckets[key]
        if not b then
          b = { hi = -math.huge, lo = math.huge, entries = {} }
          buckets[key] = b
          order[#order + 1] = key
        end
        if hi and hi > b.hi then b.hi = hi end
        if lo and lo < b.lo then b.lo = lo end
        table.insert(b.entries, { dt = dt, icon = code or "" })
      end
    end
    p:close()

    -- Build exactly today→+4 in chronological order
    local built = 0
    table.sort(order) -- ensure chronological
    for _, key in ipairs(order) do
      if built >= 5 then break end
      -- only take days >= today (local)
      local y = tonumber(key:sub(1, 4)) or 1970
      local m = tonumber(key:sub(6, 7)) or 1
      local d = tonumber(key:sub(9, 10)) or 1
      local day_noon = os.time { year = y, month = m, day = d, hour = 12, min = 0, sec = 0 }
      if day_noon >= (noon_today - 43200) then -- allow same-day tolerance
        local b = buckets[key]
        if b and b.hi ~= -math.huge and b.lo ~= math.huge and #b.entries > 0 then
          -- choose icon nearest local noon, then coerce to day icon
          local best_icon, best_diff = b.entries[1].icon, math.huge
          for _, e in ipairs(b.entries) do
            local diff = math.abs(e.dt - day_noon)
            if diff < best_diff then
              best_diff = diff; best_icon = e.icon
            end
          end
          local any_dt = b.entries[1].dt
          result[#result + 1] = {
            ts       = any_dt,
            date_str = string.format("%s %s", os.date("%b", any_dt), os.date("%a", any_dt)),
            hi       = math.floor(b.hi + 0.5),
            lo       = math.floor(b.lo + 0.5),
            icon     = day_icon(best_icon or ""),
          }
          built = built + 1
        end
      end
    end
  end

  return result
end




-- =====================================================================
-- 5. Drawing: 5-day forecast tiles
--    Called via: ${lua_parse owm draw_forecast_placeholder}
--    Layout driven by theme.weather.forecast.* (origin, tile size, gaps...)
-- =====================================================================
function conky_owm_draw_forecast_placeholder()
  if not has_cairo or not conky_window then return "" end

  -- Local PNG helper (Cairo only)
  local function draw_png_centered_cairo_local(cr, path, cx, cy, size)
    local img = cairo_image_surface_create_from_png(path)
    if (not img) or (cairo_surface_status(img) ~= 0) then
      if img then cairo_surface_destroy(img) end
      return false
    end
    local w = cairo_image_surface_get_width(img)
    local h = cairo_image_surface_get_height(img)
    if (not w or w == 0) or (not h or h == 0) then
      cairo_surface_destroy(img)
      return false
    end
    local scale = size / math.max(w, h)
    local sw, sh = w * scale, h * scale
    local ox, oy = cx - (sw / 2), cy - (sh / 2)

    cairo_save(cr)
    cairo_translate(cr, ox, oy)
    cairo_scale(cr, scale, scale)
    cairo_set_source_surface(cr, img, 0, 0)
    cairo_paint(cr)
    cairo_restore(cr)

    cairo_surface_destroy(img)
    return true
  end

  -- Cairo setup
  local cs = cairo_xlib_surface_create(conky_window.display,
    conky_window.drawable,
    conky_window.visual,
    conky_window.width,
    conky_window.height)
  local cr = cairo_create(cs)
  cairo_save(cr)

  -- theme getter with weather.* fallback
  local function tget_or(path, default)
    local v = tget(THEME, path)
    if v ~= nil then return v end
    if path:sub(1, 8) == "weather." then
      local alt = path:gsub("^weather%.", "")
      v = tget(THEME, alt)
      if v ~= nil then return v end
    end
    return default
  end

  local cfg    = tget_or("weather.forecast", nil) or tget_or("forecast", nil) or {}
  local origin = cfg.origin or { x = 165, y = 260 }
  local tiles  = cfg.tiles or 5
  local gap    = cfg.gap or 34
  local tile   = cfg.tile or { w = 64, h = 110 }
  local alpha  = (cfg.alpha ~= nil) and cfg.alpha or 1.0

  local date   = cfg.date or { pt = 11, dy = 0, color = { 0.85, 0.85, 0.85, 1.0 } }
  local icon   = cfg.icon or { size = 44, dy = 20, dir = os.getenv("HOME") .. "/.cache/conky/icons" }
  local temps  = cfg.temps or { pt = 12, dy = 74, color_hi = { 1, 1, 1, 1 }, color_lo = { 0.7, 0.7, 0.7, 1 } }

  -- text helper
  local function draw_centered_text(x, y, text, pt, color)
    cairo_select_font_face(cr, "DejaVu Sans Mono", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
    cairo_set_font_size(cr, pt)
    cairo_set_source_rgba(cr, color[1], color[2], color[3], (color[4] or 1) * alpha)
    local ext = cairo_text_extents_t:create()
    cairo_text_extents(cr, text, ext)
    cairo_move_to(cr, x - ext.width / 2 - ext.x_bearing, y - ext.height / 2 - ext.y_bearing)
    cairo_show_text(cr, text)
    cairo_new_path(cr)
  end

  -- real forecast array
  local days = read_forecast_5() -- { date_str, hi, lo, icon } x up to 5

  for i = 0, tiles - 1 do
    local x  = origin.x + i * (tile.w + gap)
    local y  = origin.y
    local cx = x + tile.w / 2
    local d  = days[i + 1]

    -- Two-line date label: TODAY first (then +1..+4), weekday slightly larger
    do
      -- local noon today (numbers, not strings, to appease linters)
      local Y          = math.floor(tonumber(os.date("%Y")) or 0)
      local M          = math.floor(tonumber(os.date("%m")) or 0)
      local D          = math.floor(tonumber(os.date("%d")) or 0)
      local noon_today = os.time { year = Y, month = M, day = D, hour = 12, min = 0, sec = 0 }

      -- tile i = today + i days
      local ts         = noon_today + (i * 86400)
      local base       = (date.pt or 11)
      local w_pt       = base + 2             -- weekday a bit larger
      local dow        = os.date("%a", ts)    -- e.g., Thu
      local mdy        = os.date("%b %e", ts) -- e.g., Nov  6

      local top_y      = y + (date.dy or 0) + w_pt
      draw_centered_text(cx, top_y, dow, w_pt, date.color)
      draw_centered_text(cx, top_y + base + 2, mdy, base, date.color)
    end




    -- icon PNG centered; fallback to hollow circle
    do
      local size = icon.size or 44
      local ic_y = y + (icon.dy or 20) + size / 2
      local dir  = icon.dir or (os.getenv("HOME") .. "/.cache/conky/icons")
      local path = string.format("%s/fc%d.png", dir, i)

      local ok   = draw_png_centered_cairo_local(cr, path, cx, ic_y, size)
      if not ok then
        cairo_set_line_width(cr, 1.5)
        cairo_set_source_rgba(cr, 0.8, 0.8, 0.8, 0.6 * alpha)
        cairo_arc(cr, cx, ic_y, size / 2, 0, 2 * math.pi)
        cairo_stroke(cr)
        cairo_new_path(cr)
      end
    end

    -- temps
    local hi_txt = (d and d.hi) and string.format("%d", d.hi) or "72°"
    local lo_txt = (d and d.lo) and string.format("%d", d.lo) or "58°"
    local t_y = y + (temps.dy or 74)
    draw_centered_text(cx, t_y, hi_txt, temps.pt, temps.color_hi)
    draw_centered_text(cx, t_y + temps.pt + 2, lo_txt, temps.pt, temps.color_lo)
  end

  cairo_restore(cr)
  cairo_destroy(cr)
  cairo_surface_destroy(cs)
  return ""
end

-- =====================================================================
-- 6. Sunrise / sunset time labels at arc ends
--    Called via: ${lua_parse owm sun_labels}
--    Behavior:
--      - Daytime:  left = "Sunset HH:MM", right = "Sunrise HH:MM"
--      - Night:    left = "Sunrise HH:MM", right = "Sunset HH:MM"
-- =====================================================================
function conky_owm_sun_labels()
  if not has_cairo or not conky_window then return "" end

  local cs = cairo_xlib_surface_create(conky_window.display,
    conky_window.drawable,
    conky_window.visual,
    conky_window.width,
    conky_window.height)
  local cr = cairo_create(cs)

  cairo_save(cr)

  local cx, cy, r, ARC_START, ARC_END = get_arc_geometry()

  -- Endpoints (left/right anchors)
  local lx, ly                        = pt_on_arc(cx, cy, r, ARC_START)
  local rx, ry                        = pt_on_arc(cx, cy, r, ARC_END)

  -- --- theme-driven placement for time labels (under weather.*) ---
  local time_pt                       = tonumber(tget(THEME, "weather.sun_time_labels.pt")) or 12
  local time_col                      = tget(THEME, "weather.sun_time_labels.color") or { 0.63, 0.63, 0.63, 1.0 }
  if type(time_col) ~= "table" then time_col = { 0.63, 0.63, 0.63, 1.0 } end

  local hl_dy       = tonumber(tget(THEME, "horizon_labels.dy")) or 18
  local time_dy     = tonumber(tget(THEME, "weather.sun_time_labels.dy")) or (hl_dy + 14)
  local lxo         = tonumber(tget(THEME, "weather.sun_time_labels.lx_offset")) or 0
  local rxo         = tonumber(tget(THEME, "weather.sun_time_labels.rx_offset")) or 0

  ly, ry            = ly + time_dy, ry + time_dy
  lx, rx            = lx + lxo, rx + rxo

  -- Times + night flip
  local sr_ts       = tonumber(read_field(".sys.sunrise") or "")
  local ss_ts       = tonumber(read_field(".sys.sunset") or "")
  local sunrise     = fmt_hhmm(sr_ts)
  local sunset      = fmt_hhmm(ss_ts)
  local now         = os.time()
  local is_night    = (sr_ts and ss_ts) and (now < sr_ts or now > ss_ts)

  local left_label  = is_night and ("Sunrise " .. (sunrise ~= "" and sunrise or "--:--"))
      or ("Sunset " .. (sunset ~= "" and sunset or "--:--"))
  local right_label = is_night and ("Sunset " .. (sunset ~= "" and sunset or "--:--"))
      or ("Sunrise " .. (sunrise ~= "" and sunrise or "--:--"))

  -- Draw text as path+fill (no path leaks), centered on anchors
  cairo_select_font_face(cr, "DejaVu Sans Mono", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
  cairo_set_font_size(cr, time_pt)
  cairo_set_source_rgba(cr, time_col[1], time_col[2], time_col[3], time_col[4])

  local ext = cairo_text_extents_t:create()

  cairo_text_extents(cr, left_label, ext)
  cairo_move_to(cr, lx - (ext.width / 2 + ext.x_bearing), ly)
  cairo_text_path(cr, left_label); cairo_fill(cr)

  cairo_text_extents(cr, right_label, ext)
  cairo_move_to(cr, rx - (ext.width / 2 + ext.x_bearing), ry)
  cairo_text_path(cr, right_label); cairo_fill(cr)

  cairo_new_path(cr)
  cairo_restore(cr)
  cairo_destroy(cr)
  cairo_surface_destroy(cs)
  return ""
end

-- Back-compatible alias for configs using conky_owm_sun_labels_call
function conky_owm_sun_labels_call() return conky_owm_sun_labels() end

-- =====================================================================
-- 7. Aviation weather
--    - METAR:       ${lua_parse metar}
--    - TAF:         ${lua_parse taf}
--    - Advisories:  ${lua_parse advisories}
--    Scripts:
--      metar_ob.sh, taf_wrap.sh, airsig_filter.sh
-- =====================================================================
-- METAR: fetch + wrap to a max line count, with optional left padding
function conky_metar()
  -- on/off
  local enabled = tget(THEME, "weather.metar.enabled")
  if enabled == false then return "" end

  local home    = os.getenv("HOME") or ""
  local station = (tget(THEME, "weather.metar.station") or "KMEM")
  local w       = tonumber(tget(THEME, "weather.metar.wrap_col")) or 40
  local cols    = tonumber(tget(THEME, "weather.metar.pad_cols")) or 0
  local maxl    = tonumber(tget(THEME, "weather.metar.max_lines")) or 2

  -- call: metar_ob.sh <STATION> <WRAP_COL>
  local cmd     = string.format("%q %q %d",
    home .. "/.config/conky/gtex62-clean-suite/scripts/metar_ob.sh", station, w)

  local p       = io.popen(cmd, "r"); if not p then return "" end
  local out = p:read("*a") or ""; p:close()
  out = (out:gsub("%s+$", ""))
  if out == "" then return "" end

  -- enforce max_lines with ellipsis on the last visible line
  if maxl and maxl > 0 then
    local lines, count = {}, 0
    for line in out:gmatch("[^\n]+") do
      table.insert(lines, line)
      count = count + 1
    end
    if count > maxl then
      lines[maxl] = (lines[maxl] or "") .. "…"
      while #lines > maxl do table.remove(lines) end
      out = table.concat(lines, "\n")
    end
  end

  -- left padding in columns (spaces)
  if cols > 0 then
    local pad = string.rep(" ", cols)
    out = pad .. out:gsub("\n", "\n" .. pad)
  end
  return out
end

-- TAF: cleaned first line, wrapped, with hanging indent for continuation lines
function conky_taf()
  -- on/off
  local enabled = tget(THEME, "weather.taf.enabled")
  if enabled == false then return "" end

  local home    = os.getenv("HOME") or ""
  local station = (tget(THEME, "weather.taf.station")
    or tget(THEME, "weather.metar.station") or "KMEM")
  local wrap    = tonumber(tget(THEME, "weather.taf.wrap_col"))
      or tonumber(tget(THEME, "weather.metar.wrap_col")) or 40
  local cols    = tonumber(tget(THEME, "weather.taf.pad_cols"))
      or tonumber(tget(THEME, "weather.metar.pad_cols")) or 0
  local maxl    = tonumber(tget(THEME, "weather.taf.max_lines")) or 4
  local indent  = tonumber(tget(THEME, "weather.taf.indent_cols")) or 0

  -- local, safe helpers
  local function srep(ch, n)
    if not n or n <= 0 then return "" end
    local out = {}
    for i = 1, n do out[i] = ch end
    return table.concat(out)
  end

  -- taf_wrap.sh: wraps & caps lines already
  local cmd = string.format("%q %d %d %q",
    home .. "/.config/conky/gtex62-clean-suite/scripts/taf_wrap.sh", wrap, maxl, station)
  local p = io.popen(cmd, "r"); if not p then return "" end
  local raw = p:read("*a") or ""; p:close()
  raw = (raw:gsub("%s+$", ""))
  if raw == "" then return "" end

  -- split lines
  local lines = {}
  for line in raw:gmatch("[^\n]+") do lines[#lines + 1] = line end
  if #lines == 0 then return "" end

  -- >>> FIRST-LINE CLEANUP: drop leading "TAF ", ensure station first
  do
    local l1 = lines[1]

    -- 1) drop leading "TAF " (case-insensitive)
    l1 = l1:gsub("^[Tt][Aa][Ff]%s+", "")

    -- 2) If it begins with "AMD <STN> ..." → "<STN> AMD ..."
    l1 = l1:gsub("^AMD%s+([%w][%w][%w][%w])%s+", "%1 AMD ")

    -- 3) If it begins with "COR <STN> ..." → "<STN> COR ..."
    l1 = l1:gsub("^COR%s+([%w][%w][%w][%w])%s+", "%1 COR ")

    lines[1] = l1
  end
  -- <<< END FIRST-LINE CLEANUP

  -- compose margins: pad_cols for line 1, pad_cols+indent for lines 2+
  local pad  = srep(" ", cols)
  local hang = srep(" ", indent)
  for i = 1, #lines do
    if i == 1 then
      lines[i] = pad .. lines[i]
    else
      lines[i] = pad .. hang .. lines[i]
    end
  end

  return table.concat(lines, "\n")
end

-- SIGMET / AIRMET advisories: TSV → wrapped human-readable lines
function conky_advisories()
  -- On/off
  local enabled = tget(THEME, "weather.advisories.enabled")
  if enabled == false then return "" end

  local home    = os.getenv("HOME") or ""
  local station = (tget(THEME, "weather.advisories.station")
    or tget(THEME, "weather.metar.station") or "KMEM")
  local radius  = tonumber(tget(THEME, "weather.advisories.radius_nm")) or 300
  local wrap    = tonumber(tget(THEME, "weather.advisories.wrap_col"))
      or tonumber(tget(THEME, "weather.metar.wrap_col")) or 40
  local cols    = tonumber(tget(THEME, "weather.advisories.pad_cols"))
      or tonumber(tget(THEME, "weather.metar.pad_cols")) or 0
  local maxl    = tonumber(tget(THEME, "weather.advisories.max_lines")) or 6

  -- Get TSV rows within radius: kind\tphen\tregion\tzone\tfrom\tto
  local cmd     = string.format("%q %q %d",
    home .. "/.config/conky/scripts/airsig_filter.sh", station, radius)
  local p       = io.popen(cmd, "r"); if not p then return "" end
  local raw = p:read("*a") or ""; p:close()
  raw = (raw:gsub("%s+$", ""))

  -- NEW: if none found, show a short message
  if raw == "" then
    local msg = string.format("No SIGMET/AIRMET within %d NM of %s", radius, station)
    if cols and cols > 0 then msg = string.rep(" ", cols) .. msg end
    return msg
  end

  -- Build readable lines from TSV
  local lines = {}
  for row in raw:gmatch("[^\n]+") do
    local k, ph, reg, zn, frm, to = row:match("([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)")
    local txt = string.format("%s %s %s %s %s–%s", k or "", ph or "", reg or "", zn or "", frm or "", to or "")
    lines[#lines + 1] = (txt:gsub("%s+", " "):gsub("%s–%s", "–"))
  end
  if #lines == 0 then
    local msg = string.format("No SIGMET/AIRMET within %d NM of %s", radius, station)
    if cols and cols > 0 then msg = string.rep(" ", cols) .. msg end
    return msg
  end

  -- Word-wrap each line to `wrap`
  local function wrap_line(s, width)
    if width <= 0 or #s <= width then return { s } end
    local res = {}
    local i = 1
    while i <= #s do
      local j = math.min(i + width - 1, #s)
      if j < #s and s:sub(j + 1, j + 1) ~= " " then
        local k = s:sub(i, j):match(".*()[ ]")
        if k and k >= i then j = k end
      end
      res[#res + 1] = (s:sub(i, j)):gsub("[ ]+$", "")
      i = j + 1
      while s:sub(i, i) == " " do i = i + 1 end
    end
    return res
  end

  local wrapped = {}
  for idx = 1, #lines do
    local parts = wrap_line(lines[idx], wrap)
    for j = 1, #parts do wrapped[#wrapped + 1] = parts[j] end
  end

  -- Enforce total max_lines, ellipsis on last if truncated
  if maxl and maxl > 0 and #wrapped > maxl then
    wrapped[maxl] = (wrapped[maxl] or "") .. "…"
    while #wrapped > maxl do wrapped[#wrapped] = nil end
  end

  -- Left padding
  if cols and cols > 0 then
    local pad = string.rep(" ", cols)
    for i = 1, #wrapped do wrapped[i] = pad .. wrapped[i] end
  end

  return table.concat(wrapped, "\n")
end
