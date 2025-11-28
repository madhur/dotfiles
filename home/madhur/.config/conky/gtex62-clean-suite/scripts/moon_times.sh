#!/usr/bin/env bash
# Usage: moon_times.sh <lat> <lon>
# Prints: MOON_RISE_TS=<unix> and MOON_SET_TS=<unix> (UTC-based epoch seconds)

lat="${1:-35.1116}"
lon="${2:- -89.756}"

python3 - <<'PY' "$lat" "$lon"
import sys, datetime as dt
try:
    import ephem
except ImportError:
    print("ERROR: PyEphem not installed. Run:  pip3 install --user ephem")
    sys.exit(1)

lat, lon = float(sys.argv[1]), float(sys.argv[2])
o = ephem.Observer()
o.lat, o.lon = str(lat), str(lon)
o.elevation = 0
o.date = ephem.now()
m = ephem.Moon()

UTC = dt.timezone.utc
now = dt.datetime.now(UTC)

def ts(x): return int(x.datetime().replace(tzinfo=UTC).timestamp())
def safe(fn):
    try: return fn(m)
    except (ephem.AlwaysUpError, ephem.NeverUpError): return None

prev_rise = safe(o.previous_rising)
prev_set  = safe(o.previous_setting)
next_rise = safe(o.next_rising)
next_set  = safe(o.next_setting)

rise_ts = set_ts = None

def span_ok(r_ts, s_ts, max_hours=18):
    return (s_ts is not None and r_ts is not None
            and 0 < (s_ts - r_ts) <= max_hours*3600)

# Candidate epochs
pr_ts = ts(prev_rise) if prev_rise else None
ps_ts = ts(prev_set)  if prev_set  else None
nr_ts = ts(next_rise) if next_rise else None
ns_ts = ts(next_set)  if next_set  else None
now_ts = int(now.timestamp())

# 1) If currently up, prefer [prev_rise, next_set] but clamp duration
if pr_ts and ns_ts and pr_ts <= now_ts <= ns_ts and span_ok(pr_ts, ns_ts):
    rise_ts, set_ts = pr_ts, ns_ts

# 2) Otherwise, if the next interval is sane, use [next_rise, next_set]
if rise_ts is None and nr_ts and ns_ts and nr_ts < ns_ts and span_ok(nr_ts, ns_ts):
    rise_ts, set_ts = nr_ts, ns_ts

# 3) Fallbacks (rare): try previous-day [prev_rise, prev_set] if it brackets now
if rise_ts is None and pr_ts and ps_ts and pr_ts < ps_ts and pr_ts <= now_ts <= ps_ts and span_ok(pr_ts, ps_ts):
    rise_ts, set_ts = pr_ts, ps_ts


print(f"MOON_RISE_TS={rise_ts}")
print(f"MOON_SET_TS={set_ts}")
PY
