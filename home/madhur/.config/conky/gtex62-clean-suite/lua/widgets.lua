---@diagnostic disable: lowercase-global

-- ~/.config/conky/widgets.lua
-- Helpers for Rainmeter-style Conky widget:
-- - Fixed-length colored slash bars (reads colors/count from theme.lua)
-- - Percent formatting with chosen decimals
-- - Separator line from theme (configurable char/count)
-- - Indent spacing from theme
-- - Trimmed process names (CPU / MEM lists)
-- - Tight numeric formatting (no ugly left padding)
-- NOTE: Avoid passing string.gsub(...) directly to tonumber/return; capture first value.

local theme = dofile(os.getenv("HOME") .. "/.config/conky/gtex62-clean-suite/theme.lua")

-- normalize hex colors: accept 'RRGGBB' or '#RRGGBB'
local function norm_hex(c, fallback)
  local s = tostring(c or "")
  s = s:gsub("%s+", "")
  if s == "" then return fallback end
  if s:sub(1, 1) ~= "#" and s:match("^%x%x%x%x%x%x$") then
    return "#" .. s
  end
  return s
end

-- config pulled from theme.lua with sensible fallbacks
local CFG = {
  slash_count = theme.slash_count or 20,
  fill        = norm_hex(theme.bar_fill_color, "#FFD54A"),
  empty       = norm_hex(theme.bar_empty_color, "#5A5A5A"),
  char        = theme.bar_char or "/",
  sep_char    = theme.sep_char or "-",
  sep_count   = theme.sep_count or 24,
  indent      = string.rep(" ", theme.indent_spaces or 3),
}

-- utils
local function clamp(x, lo, hi)
  if x < lo then return lo elseif x > hi then return hi end
  return x
end

-- parse a number possibly coming from a ${var}; strip spaces/% then tonumber
local function parse_num(x, default)
  local s = conky_parse(tostring(x or "")) -- expand ${...}
  s = s:gsub("%%", "")                     -- strip %
  s = s:gsub("%s+", "")                    -- strip spaces
  local n = tonumber(s)
  return n or default
end

-- █ Fixed-length slash bar (e.g., 20 slashes), colored fill/empty from theme
-- usage in conky.text:
--   ${lua_parse slash_fixed_auto ${cpu}}
--   ${lua_parse slash_fixed_auto ${memperc}}
function conky_slash_fixed_auto(pct)
  local p      = clamp(parse_num(pct, 0), 0, 100)
  local total  = CFG.slash_count
  local filled = math.floor((p / 100) * total)
  if filled > total then filled = total end
  local empty = total - filled
  local out   = string.format(
    "${color %s}%s${color %s}%s${color}",
    CFG.fill, string.rep(CFG.char, filled),
    CFG.empty, string.rep(CFG.char, empty)
  )
  -- ensure color tags render
  return conky_parse(out)
end

-- █ Percent formatter with chosen decimals (tight; no leading spaces)
-- usage: ${lua_parse pct ${cpu} 3}
function conky_pct(pct, decimals)
  local p = parse_num(pct, 0)
  local d = tonumber(decimals) or 1
  return string.format("%." .. d .. "f%%", p)
end

-- █ Separator line (sep_char repeated sep_count)
-- usage: ${lua_parse sep_auto}
function conky_sep_auto()
  return string.rep(CFG.sep_char, CFG.sep_count)
end

-- █ Indent (just spaces) before process rows
-- usage: ${lua_parse indent}
function conky_indent()
  return CFG.indent
end

-- █ Safe name trimming with ellipsis (keeps columns neat)
local function cut_with_ellipsis(s, maxch)
  local m = tonumber(maxch) or 26
  s = tostring(s or "")
  if #s > m then
    if m >= 1 then return s:sub(1, m - 1) .. "…" end
  end
  return s
end

-- █ Top CPU process NAME (1..5), trimmed
-- usage: ${lua_parse topname 1 26}
function conky_topname(idx, maxch)
  local i = tonumber(idx) or 1
  local raw = conky_parse(string.format("${top name %d}", i)) or ""
  return cut_with_ellipsis(raw, maxch)
end

-- █ Top MEM process NAME (1..5), trimmed
-- usage: ${lua_parse topmemname 1 26}
function conky_topmemname(idx, maxch)
  local i = tonumber(idx) or 1
  local raw = conky_parse(string.format("${top_mem name %d}", i)) or ""
  return cut_with_ellipsis(raw, maxch)
end

-- █ Tight CPU % value for top-N (no left padding)
-- usage: ${lua_parse topcpu 1 2}
function conky_topcpu(idx, decimals)
  local i = tonumber(idx) or 1
  local raw = conky_parse(string.format("${top cpu %d}", i)) or ""
  -- IMPORTANT: capture only the first return of gsub
  local cleaned = raw:gsub("%s+", "")
  local n = tonumber(cleaned) or 0
  local d = tonumber(decimals) or 2
  return string.format("%." .. d .. "f%%", n)
end

-- █ Tight mem_res for top-N (trim leading spaces)
-- usage: ${lua_parse topmemres 1}
function conky_topmemres(idx)
  local i = tonumber(idx) or 1
  local raw = conky_parse(string.format("${top_mem mem_res %d}", i)) or ""
  -- capture first return of gsub to avoid extra return values
  local cleaned = raw:gsub("^%s+", "")
  return cleaned
end
