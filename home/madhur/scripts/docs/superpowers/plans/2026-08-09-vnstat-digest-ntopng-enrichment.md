# vnstat Digest — ntopng Enrichment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two tables — top devices and top applications by traffic, both for "yesterday" — to the existing `vnstat_digest.py` email, sourced from ntopng's flow journal, degrading gracefully to no-op when that data isn't available.

**Architecture:** Three pure aggregation functions (`parse_flow_lines`, `top_talkers`, `top_apps`) feed a render-time helper in `build_email` that truncates to `TOP_N` and derives the "+k more" note from the same untruncated list. An impure `fetch_flow_lines`/`gather_ntopng` layer (subprocess + `sudo journalctl`) sits below them, wrapped in a best-effort `try/except` that returns `None` on any failure — never raises into `gather()`/`main()`.

**Tech Stack:** Same as the base digest — stdlib `subprocess`/`json`, no new dependencies. Reads the `ntopng-flows` journald namespace via the same `sudo -n journalctl --namespace=ntopng-flows -o cat` invocation `/usr/local/bin/bigflows` already uses (passwordless sudo already configured on this box).

## Global Constraints

- All new code lands in the existing `/home/madhur/scripts/vnstat_digest.py` and `/home/madhur/scripts/tests/test_vnstat_digest.py` — no new files except one edited line in `vnstat-digest.env`.
- `top_talkers`/`top_apps` return the **full, untruncated, descending-sorted** list — `[{"label": str, "bytes": int}, ...]`. Truncation to `TOP_N` and the remainder note happen in `build_email`, not in the aggregators (per spec — keeps the shown rows and the "+k more" note mathematically unable to disagree).
- `gather_ntopng()` **never raises**. It catches `FileNotFoundError` and `subprocess.CalledProcessError` around the `journalctl` call, and treats an empty parsed-flow list as a (non-exceptional) "nothing to show" case. Either way it returns `None`, logs one `WARNING:` line to stderr, and the digest sends without the two tables.
- No new env var to enable/disable ntopng enrichment — the empty-data path already self-disables it.
- Same test convention as the base digest: plain `assert`-based tests in `tests/test_vnstat_digest.py`, `run_test(name, fn)` PASS/FAIL runner, run via `python3 tests/test_vnstat_digest.py`. `fetch_flow_lines`/`gather_ntopng` (subprocess I/O) are verified manually, not unit-tested — same convention as `fetch_raw`/`gather` in the base digest.
- `/home/madhur/scripts` is **not a git repository** — no "Commit" steps; each task ends with a verification run instead (matches the base digest's plan).
- Live-confirmed before writing this plan: the flow journal has **zero records for yesterday (2026-08-08)** — ntopng's own logging only started today. Task 3's manual verification exercises the real "no data" degradation path (not a synthetic one) and separately sanity-checks that the `sudo`/`journalctl` mechanics themselves work, using a recent time window instead of "yesterday."

---

## File Structure

- **Modify:** `/home/madhur/scripts/vnstat_digest.py` — add `parse_flow_lines`, `top_talkers`, `top_apps` (pure aggregation); extend `_table()` with a `note` param; add `_ntopng_tables()` render helper and wire it into `build_email()`; add `fetch_flow_lines`, `gather_ntopng` (orchestration); wire `gather_ntopng()` into `gather()`; add `TOP_N` config.
- **Modify:** `/home/madhur/scripts/tests/test_vnstat_digest.py` — add tests for all new pure functions.
- **Modify:** `/home/madhur/scripts/vnstat-digest.env` — add `TOP_N=5`.

---

### Task 1: Flow parsing & aggregation (pure)

**Files:**
- Modify: `/home/madhur/scripts/vnstat_digest.py`
- Modify: `/home/madhur/scripts/tests/test_vnstat_digest.py`

**Interfaces:**
- Consumes: nothing new (works on plain `dict`/`str` data).
- Produces: `parse_flow_lines(lines: list[str]) -> list[dict]`, `top_talkers(flows: list[dict]) -> list[dict]`, `top_apps(flows: list[dict]) -> list[dict]`. Both aggregators' output shape (`[{"label": str, "bytes": int}, ...]`, sorted descending, untruncated) is what Task 2's `build_email` and Task 3's `gather_ntopng` consume.

- [ ] **Step 1: Write the failing tests**

Add to `/home/madhur/scripts/tests/test_vnstat_digest.py`, after the `RAW_FIXTURE` block and before the `test_extract_traffic_finds_matching_interface` tests (order within the file doesn't matter functionally — this placement keeps fixtures near their tests):

```python
# Fixture: synthetic ntopng flow records covering the attribution cases
# top_talkers/top_apps must handle — local->remote, remote->local,
# local<->local (counts for both endpoints), an unresolved hostname
# (falls back to IP), and a flow missing L7_PROTO_NAME (-> "Unknown").
FLOW_FIXTURE = [
    {"SRC_ADDR_LOCAL": True, "DST_ADDR_LOCAL": False, "SRC_NAME": "kafka",
     "IPV4_SRC_ADDR": "192.168.1.82", "DST_NAME": "", "IPV4_DST_ADDR": "1.2.3.4",
     "L7_PROTO_NAME": "TLS", "IN_BYTES": 600, "OUT_BYTES": 400},
    {"SRC_ADDR_LOCAL": False, "DST_ADDR_LOCAL": True, "SRC_NAME": "",
     "IPV4_SRC_ADDR": "5.6.7.8", "DST_NAME": "Mac", "IPV4_DST_ADDR": "192.168.1.211",
     "L7_PROTO_NAME": "TLS", "IN_BYTES": 300, "OUT_BYTES": 200},
    {"SRC_ADDR_LOCAL": True, "DST_ADDR_LOCAL": True, "SRC_NAME": "kafka",
     "IPV4_SRC_ADDR": "192.168.1.82", "DST_NAME": "router", "IPV4_DST_ADDR": "192.168.1.1",
     "L7_PROTO_NAME": "HTTP.SOAP", "IN_BYTES": 100, "OUT_BYTES": 100},
    {"SRC_ADDR_LOCAL": True, "DST_ADDR_LOCAL": False, "SRC_NAME": "Mac",
     "IPV4_SRC_ADDR": "192.168.1.211", "DST_NAME": "", "IPV4_DST_ADDR": "9.9.9.9",
     "L7_PROTO_NAME": "BitTorrent", "IN_BYTES": 30, "OUT_BYTES": 20},
    {"SRC_ADDR_LOCAL": True, "DST_ADDR_LOCAL": False, "SRC_NAME": "kafka",
     "IPV4_SRC_ADDR": "192.168.1.82", "IPV4_DST_ADDR": "9.9.9.10",
     "IN_BYTES": 10, "OUT_BYTES": 10},
]


def test_parse_flow_lines_skips_non_json_and_blank_lines():
    lines = [
        '{"a": 1}',
        '',
        '   ',
        'not json at all',
        '{"b": 2}',
        '{"broken": ',
    ]
    result = vd.parse_flow_lines(lines)
    assert result == [{"a": 1}, {"b": 2}]


def test_top_talkers_attributes_by_local_side_and_ranks_descending():
    # kafka: 1000 (flow 1) + 200 (flow 3) + 20 (flow 5) = 1220
    # Mac:   500 (flow 2) + 50 (flow 4) = 550
    # router: 200 (flow 3, local<->local counts for both endpoints)
    result = vd.top_talkers(FLOW_FIXTURE)
    assert result == [
        {"label": "kafka", "bytes": 1220},
        {"label": "Mac", "bytes": 550},
        {"label": "router", "bytes": 200},
    ]


def test_top_talkers_falls_back_to_ip_when_name_unresolved():
    flows = [{"SRC_ADDR_LOCAL": True, "DST_ADDR_LOCAL": False, "SRC_NAME": "",
              "IPV4_SRC_ADDR": "192.168.1.50", "IN_BYTES": 100, "OUT_BYTES": 0}]
    result = vd.top_talkers(flows)
    assert result == [{"label": "192.168.1.50", "bytes": 100}]


def test_top_apps_ranks_descending_and_buckets_missing_proto_as_unknown():
    # TLS: 1000 + 500 = 1500, HTTP.SOAP: 200, BitTorrent: 50, Unknown: 20
    result = vd.top_apps(FLOW_FIXTURE)
    assert result == [
        {"label": "TLS", "bytes": 1500},
        {"label": "HTTP.SOAP", "bytes": 200},
        {"label": "BitTorrent", "bytes": 50},
        {"label": "Unknown", "bytes": 20},
    ]


def test_top_talkers_and_top_apps_return_empty_list_for_no_flows():
    assert vd.top_talkers([]) == []
    assert vd.top_apps([]) == []
```

Then extend the `if __name__ ==` runner block (keep every existing `run_test(...)` call, add these 5 before the summary/exit lines):

```python
    run_test("parse_flow_lines skips non-JSON and blank lines", test_parse_flow_lines_skips_non_json_and_blank_lines)
    run_test("top_talkers attributes by local side and ranks descending", test_top_talkers_attributes_by_local_side_and_ranks_descending)
    run_test("top_talkers falls back to IP when name unresolved", test_top_talkers_falls_back_to_ip_when_name_unresolved)
    run_test("top_apps ranks descending and buckets missing proto as Unknown", test_top_apps_ranks_descending_and_buckets_missing_proto_as_unknown)
    run_test("top_talkers and top_apps return empty list for no flows", test_top_talkers_and_top_apps_return_empty_list_for_no_flows)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 /home/madhur/scripts/tests/test_vnstat_digest.py`
Expected: the 5 new tests `FAIL` with `AttributeError: module 'vnstat_digest' has no attribute 'parse_flow_lines'` (and similarly for `top_talkers`/`top_apps`); all 16 existing tests still `PASS`.

- [ ] **Step 3: Write the minimal implementation**

In `/home/madhur/scripts/vnstat_digest.py`, insert a new section directly after the `derive()` function (i.e. after the line `return {"yesterday": yesterday_entry, "month": month_entry, "rows": rows}` and before the `# Email content (pure)` section header):

```python

# --------------------------------------------------------------------------- #
# ntopng flow-journal aggregation (pure)
# --------------------------------------------------------------------------- #
def parse_flow_lines(lines: list[str]) -> list[dict]:
    """Parse `journalctl -o cat` output lines into flow record dicts.

    Skips blank lines and anything that isn't valid JSON — the namespace can
    carry other syslog noise alongside ntopng's flow records."""
    records = []
    for line in lines:
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            records.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return records


def top_talkers(flows: list[dict]) -> list[dict]:
    """Total bytes per local device, summed across every flow it appears in
    as the local endpoint (by SRC_ADDR_LOCAL/DST_ADDR_LOCAL). A local<->local
    flow contributes to both endpoints — both devices genuinely participated.
    Devices are keyed by resolved name, falling back to IP when unresolved.
    Returns the full list sorted descending by bytes — NOT truncated;
    truncation to TOP_N happens at render time in build_email."""
    totals: dict[str, int] = {}
    for f in flows:
        total = f.get("IN_BYTES", 0) + f.get("OUT_BYTES", 0)
        if f.get("SRC_ADDR_LOCAL"):
            key = f.get("SRC_NAME") or f.get("IPV4_SRC_ADDR", "?")
            totals[key] = totals.get(key, 0) + total
        if f.get("DST_ADDR_LOCAL"):
            key = f.get("DST_NAME") or f.get("IPV4_DST_ADDR", "?")
            totals[key] = totals.get(key, 0) + total
    ranked = sorted(totals.items(), key=lambda kv: kv[1], reverse=True)
    return [{"label": k, "bytes": v} for k, v in ranked]


def top_apps(flows: list[dict]) -> list[dict]:
    """Total bytes per L7 application protocol (nDPI classification),
    summed across all flows regardless of local/remote direction. Missing
    L7_PROTO_NAME buckets as "Unknown". Returns the full list sorted
    descending by bytes — NOT truncated; see top_talkers."""
    totals: dict[str, int] = {}
    for f in flows:
        proto = f.get("L7_PROTO_NAME") or "Unknown"
        total = f.get("IN_BYTES", 0) + f.get("OUT_BYTES", 0)
        totals[proto] = totals.get(proto, 0) + total
    ranked = sorted(totals.items(), key=lambda kv: kv[1], reverse=True)
    return [{"label": k, "bytes": v} for k, v in ranked]
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 /home/madhur/scripts/tests/test_vnstat_digest.py`
Expected: `All tests passed` (21 PASS lines, 0 failures).

---

### Task 2: Render the ntopng tables in `build_email`

**Files:**
- Modify: `/home/madhur/scripts/vnstat_digest.py`
- Modify: `/home/madhur/scripts/tests/test_vnstat_digest.py`

**Interfaces:**
- Consumes: `top_talkers`/`top_apps` output shape from Task 1 (`[{"label": str, "bytes": int}, ...]`); `human()`, `_esc()`, `_cell()`, `_table()` (existing).
- Produces: `_table()` gains an optional `note: str = ""` param (backward compatible — existing call site in `build_email` for the days table is unaffected since it omits the arg). `build_email(d)`'s expected input shape grows two optional keys: `d["ntopng"]` (`{"talkers": list[dict], "apps": list[dict]} | None`, defaults to `None` via `.get()`) and `d["top_n"]` (`int`, defaults to `5` via `.get()`). Task 3's `gather()` is what actually populates these keys on the real `d`.

- [ ] **Step 1: Write the failing tests**

Add to `/home/madhur/scripts/tests/test_vnstat_digest.py`, after the existing `test_build_email_html_omits_today_marker_when_no_today_row` test:

```python
def _ntopng_ctx():
    return {
        "talkers": [
            {"label": "kafka", "bytes": 2_100_000_000},
            {"label": "Mac", "bytes": 1_400_000_000},
            {"label": "router", "bytes": 300_000_000},
            {"label": "extra1", "bytes": 100},
            {"label": "extra2", "bytes": 50},
        ],
        "apps": [
            {"label": "TLS", "bytes": 8_000_000_000},
            {"label": "YouTube", "bytes": 2_100_000_000},
            {"label": "BitTorrent", "bytes": 500_000_000},
        ],
    }


def test_build_email_renders_ntopng_tables_when_present():
    ctx = _email_ctx(ntopng=_ntopng_ctx(), top_n=3)
    _, _, html = vd.build_email(ctx)
    assert "Top devices (yesterday)" in html
    assert "kafka" in html
    assert "Top applications (yesterday)" in html
    assert "YouTube" in html
    # top_n=3 truncates talkers to kafka/Mac/router; extra1(100)+extra2(50) -> note
    assert "+2 more, totalling 150 B" in html


def test_build_email_omits_ntopng_tables_when_absent():
    ctx = _email_ctx()  # no "ntopng" key at all -> build_email must default via .get()
    _, _, html = vd.build_email(ctx)
    assert "Top devices" not in html
    assert "Top applications" not in html


def test_build_email_omits_ntopng_tables_when_none():
    ctx = _email_ctx(ntopng=None)
    _, _, html = vd.build_email(ctx)
    assert "Top devices" not in html
    assert "Top applications" not in html
```

Then extend the `if __name__ ==` runner block (keep every existing call, including the 5 added in Task 1 — append these 3 before the summary/exit lines):

```python
    run_test("build_email renders ntopng tables when present", test_build_email_renders_ntopng_tables_when_present)
    run_test("build_email omits ntopng tables when absent", test_build_email_omits_ntopng_tables_when_absent)
    run_test("build_email omits ntopng tables when None", test_build_email_omits_ntopng_tables_when_none)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 /home/madhur/scripts/tests/test_vnstat_digest.py`
Expected: the first two new tests `FAIL` (`AssertionError`, since `build_email` doesn't render anything ntopng-related yet); the third (`omits_when_none`) `PASS` already (nothing to render, matches current behavior) — that's fine, it's asserting behavior that must *keep* holding, not new behavior.

- [ ] **Step 3: Write the minimal implementation**

In `/home/madhur/scripts/vnstat_digest.py`, modify `_table()`:

```python
def _table(title: str, headers: list[tuple[str, str]], rows: list[str], note: str = "") -> str:
    if not rows:
        return ""
    head = "".join(
        f'<th style="text-align:{align};padding:6px 12px;color:#9aa0a6;font-weight:500">{_esc(label)}</th>'
        for label, align in headers
    )
    note_html = f'<p style="color:#5f6571;font-size:11px;margin:4px 12px">{note}</p>' if note else ""
    return (
        f'<h3 style="margin:24px 0 6px;color:#e8eaed;font-size:15px">{title}</h3>'
        '<table style="width:100%;border-collapse:collapse;font-size:13px">'
        f"<tr>{head}</tr>" + "".join(rows) + "</table>" + note_html
    )
```

Add a new render helper directly after `_table()` and before `build_email()`:

```python
def _ntopng_tables(ntopng: dict | None, top_n: int) -> str:
    """Render the top-devices / top-applications tables from
    gather_ntopng()'s full (untruncated) lists. Returns "" when `ntopng` is
    None — enrichment unavailable or no flow data for yesterday."""
    if not ntopng:
        return ""

    def _section(title: str, rows: list[dict], label_header: str) -> str:
        shown, rest = rows[:top_n], rows[top_n:]
        row_html = [
            f'<tr>{_cell(_esc(r["label"]))}{_cell(human(r["bytes"]), "right")}</tr>'
            for r in shown
        ]
        note = (f'+{len(rest)} more, totalling {human(sum(r["bytes"] for r in rest))}.'
                if rest else "")
        return _table(title, [(label_header, "left"), ("Traffic", "right")], row_html, note=note)

    return (_section("Top devices (yesterday)", ntopng["talkers"], "Device")
            + _section("Top applications (yesterday)", ntopng["apps"], "Application"))
```

In `build_email()`, update the docstring and insert the ntopng tables into the HTML. Change:

```python
def build_email(d: dict) -> tuple[str, str, str]:
    """d: {iface, now(date), created(date), yesterday(dict|None),
    month(dict|None), rows(list[dict])} -> (subject, plain_body, html_body)."""
```

to:

```python
def build_email(d: dict) -> tuple[str, str, str]:
    """d: {iface, now(date), created(date), yesterday(dict|None),
    month(dict|None), rows(list[dict]), ntopng(dict|None, optional, default
    None via .get()), top_n(int, optional, default 5 via .get())}
    -> (subject, plain_body, html_body)."""
```

And change the HTML assembly (the `days_table = _table(...)` call and the `html = f"""..."""` block) from:

```python
    days_table = _table(
        f'Last {len(d["rows"])} day(s)',
        [("Date", "left"), ("RX", "right"), ("TX", "right"), ("Total", "right")],
        row_html,
    )

    created_note = (f'Interface {_esc(iface)} · data since '
                     f'{_esc(d["created"].strftime("%d %b %Y"))}.')

    html = f"""<html><head><meta name="color-scheme" content="dark"><style>html,body{{margin:0;background:#1b1b1d}}</style></head>
<body style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;font-size:14px;color:#d7dade;background:#1b1b1d;padding:18px">
<p style="color:#9aa0a6;margin-top:0">vnstat · {_esc(d["now"].strftime("%A, %d %b %Y"))}</p>
{headline}
{days_table}
<hr style="border:none;border-top:1px solid #33353a;margin:22px 0">
<p style="font-size:11px;color:#5f6571">{created_note}</p>
</body></html>"""
```

to:

```python
    days_table = _table(
        f'Last {len(d["rows"])} day(s)',
        [("Date", "left"), ("RX", "right"), ("TX", "right"), ("Total", "right")],
        row_html,
    )

    ntopng_tables = _ntopng_tables(d.get("ntopng"), d.get("top_n", 5))

    created_note = (f'Interface {_esc(iface)} · data since '
                     f'{_esc(d["created"].strftime("%d %b %Y"))}.')

    html = f"""<html><head><meta name="color-scheme" content="dark"><style>html,body{{margin:0;background:#1b1b1d}}</style></head>
<body style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;font-size:14px;color:#d7dade;background:#1b1b1d;padding:18px">
<p style="color:#9aa0a6;margin-top:0">vnstat · {_esc(d["now"].strftime("%A, %d %b %Y"))}</p>
{headline}
{days_table}
{ntopng_tables}
<hr style="border:none;border-top:1px solid #33353a;margin:22px 0">
<p style="font-size:11px;color:#5f6571">{created_note}</p>
</body></html>"""
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 /home/madhur/scripts/tests/test_vnstat_digest.py`
Expected: `All tests passed` (24 PASS lines, 0 failures).

---

### Task 3: Fetch layer, orchestration, and wiring

**Files:**
- Modify: `/home/madhur/scripts/vnstat_digest.py` (no new automated tests — subprocess/sudo I/O, verified manually per Step 3/4 below, same convention as `fetch_raw`/`gather` in the base digest)
- Modify: `/home/madhur/scripts/vnstat-digest.env`

**Interfaces:**
- Consumes: `parse_flow_lines`, `top_talkers`, `top_apps` (Task 1).
- Produces: `fetch_flow_lines(since: str, until: str) -> list[str]`, `gather_ntopng(today: date) -> dict | None`. `gather()`'s return dict gains `"ntopng"` and `"top_n"` keys (consumed by Task 2's `build_email`, already implemented).

- [ ] **Step 1: Write the implementation**

In `/home/madhur/scripts/vnstat_digest.py`, add `TOP_N` to the config block — change:

```python
MAIL_FROM = os.environ.get("MAIL_FROM", "vnstat-digest@madhur.co.in")
MAIL_TO = os.environ.get("MAIL_TO", "ahuja.madhur@gmail.com")
VNSTAT_IFACE = os.environ.get("VNSTAT_IFACE", "enp5s0")
DAYS_TABLE = int(os.environ.get("DAYS_TABLE", "7"))
```

to:

```python
MAIL_FROM = os.environ.get("MAIL_FROM", "vnstat-digest@madhur.co.in")
MAIL_TO = os.environ.get("MAIL_TO", "ahuja.madhur@gmail.com")
VNSTAT_IFACE = os.environ.get("VNSTAT_IFACE", "enp5s0")
DAYS_TABLE = int(os.environ.get("DAYS_TABLE", "7"))
TOP_N = int(os.environ.get("TOP_N", "5"))
```

Update the module docstring's Config list — change:

```
Config (override via vnstat-digest.env):
  MAIL_FROM    (default vnstat-digest@madhur.co.in)
  MAIL_TO      (default ahuja.madhur@gmail.com)
  VNSTAT_IFACE (default enp5s0)
  DAYS_TABLE   (default 7)
"""
```

to:

```
Config (override via vnstat-digest.env):
  MAIL_FROM    (default vnstat-digest@madhur.co.in)
  MAIL_TO      (default ahuja.madhur@gmail.com)
  VNSTAT_IFACE (default enp5s0)
  DAYS_TABLE   (default 7)
  TOP_N        (default 5) — rows in the ntopng top-devices/top-apps tables

ntopng enrichment (top devices / top applications by traffic) reads the
`ntopng-flows` journald namespace via `sudo -n journalctl`. If that command
fails or has no data for yesterday, the two tables are silently omitted —
this digest's core vnstat numbers never depend on ntopng being present.
"""
```

Add `fetch_flow_lines` and `gather_ntopng` directly after `fetch_raw()` and before `gather()`:

```python
def fetch_flow_lines(since: str, until: str) -> list[str]:
    """Run `sudo -n journalctl --namespace=ntopng-flows -o cat` for the given
    window and return stdout split into lines. Passwordless sudo for this
    namespace is already configured on this box (shared with bigflows)."""
    out = subprocess.run(
        ["sudo", "-n", "journalctl", "--namespace=ntopng-flows", "-o", "cat",
         "--since", since, "--until", until],
        capture_output=True, text=True, check=True,
    ).stdout
    return out.splitlines()


def gather_ntopng(today: date) -> dict | None:
    """Best-effort ntopng flow-journal enrichment for yesterday: top devices
    and top applications by traffic. Returns None (never raises) if the
    journal is unreadable or has no flows for yesterday — the core vnstat
    digest doesn't depend on this."""
    since = (today - timedelta(days=1)).strftime("%Y-%m-%d 00:00:00")
    until = today.strftime("%Y-%m-%d 00:00:00")
    try:
        lines = fetch_flow_lines(since, until)
    except (FileNotFoundError, subprocess.CalledProcessError) as e:
        print(f"WARNING: ntopng enrichment skipped: {e}", file=sys.stderr)
        return None

    flows = parse_flow_lines(lines)
    if not flows:
        print("WARNING: ntopng enrichment skipped: no flows for yesterday", file=sys.stderr)
        return None

    return {"talkers": top_talkers(flows), "apps": top_apps(flows)}
```

Wire it into `gather()` — change:

```python
def gather(iface: str, days_table: int) -> dict:
    raw = fetch_raw(iface)
    traffic = extract_traffic(raw, iface)
    now = datetime.now(IST).date()
    derived = derive(traffic, now, days_table)
    created = next(e for e in raw["interfaces"] if e["name"] == iface)["created"]["date"]
    return {
        "iface": iface,
        "now": now,
        "created": _to_date(created),
        **derived,
    }
```

to:

```python
def gather(iface: str, days_table: int, top_n: int) -> dict:
    raw = fetch_raw(iface)
    traffic = extract_traffic(raw, iface)
    now = datetime.now(IST).date()
    derived = derive(traffic, now, days_table)
    created = next(e for e in raw["interfaces"] if e["name"] == iface)["created"]["date"]
    return {
        "iface": iface,
        "now": now,
        "created": _to_date(created),
        "ntopng": gather_ntopng(now),
        "top_n": top_n,
        **derived,
    }
```

And update `main()`'s call site — change:

```python
    try:
        d = gather(VNSTAT_IFACE, DAYS_TABLE)
```

to:

```python
    try:
        d = gather(VNSTAT_IFACE, DAYS_TABLE, TOP_N)
```

- [ ] **Step 2: Run the existing unit tests to confirm nothing broke**

Run: `python3 /home/madhur/scripts/tests/test_vnstat_digest.py`
Expected: `All tests passed` (24 PASS lines — `gather()`/`gather_ntopng()` aren't unit-tested, but importing the module must still succeed with no network/subprocess calls at import time).

- [ ] **Step 3: Add `TOP_N` to the env file**

In `/home/madhur/scripts/vnstat-digest.env`, add after the `DAYS_TABLE` line:

```
# Rows in the ntopng top-devices / top-applications tables (both share this
# one setting). Silently has no effect if ntopng enrichment is unavailable.
TOP_N=5
```

- [ ] **Step 4: Sanity-check the sudo/journalctl mechanics directly**

The "yesterday" window is currently empty (confirmed live during design — ntopng's logging only started today), so a normal digest run will exercise the *no-data* path, not prove the plumbing itself works. Check that separately, against a window that does have data (the last hour):

```bash
cd /home/madhur/scripts && /home/madhur/.virtualenvs/python-rsha/bin/python -c "
import vnstat_digest as vd
lines = vd.fetch_flow_lines('-1h', 'now')  # bigflows' own default relative-time style
flows = vd.parse_flow_lines(lines)
print(f'{len(lines)} lines, {len(flows)} parsed flows')
if flows:
    print('sample talker row:', vd.top_talkers(flows)[0])
    print('sample app row:', vd.top_apps(flows)[0])
"
```

Expected: a nonzero line/flow count (there's live traffic on this box), and one sample row printed from each of `top_talkers`/`top_apps` — confirms `sudo -n journalctl --namespace=ntopng-flows` really works end-to-end from this script, independent of whether "yesterday" specifically has data yet.

- [ ] **Step 5: Live run — verify the real (current) no-data degradation path**

```bash
/home/madhur/scripts/vnstat_digest.py; echo "exit=$?"
```

Expected: stderr line `WARNING: ntopng enrichment skipped: no flows for yesterday`, `exit=0`, and the usual "Sent vnstat digest -> ..." stdout line. Then check the message in Mailpit: the existing yesterday/month-to-date/days-table content is unchanged, and there is **no** "Top devices"/"Top applications" section (confirms the degradation path leaves the base digest untouched).

- [ ] **Step 6: Re-run once "yesterday" has real ntopng data (do this the day after deploying, not now)**

```bash
/home/madhur/scripts/vnstat_digest.py; echo "exit=$?"
```

Expected: no `WARNING:` line, `exit=0`, and the Mailpit message now includes both new tables. Cross-check a couple of entries against `bigflows --since "yesterday 00:00" --until "today 00:00" --min-mb 0` (or similar) run manually for the same window, to sanity-check the aggregated numbers look consistent with the raw flow list.

---

## Post-Plan Verification (do once, after all tasks — steps 1-3 now, step 4 the following day)

- [ ] Re-run `python3 /home/madhur/scripts/tests/test_vnstat_digest.py` one final time — `All tests passed` (24/24).
- [ ] `bash -n /home/madhur/scripts/every_24_hours.sh` — unaffected by this plan (no changes to that file), but confirm it's still syntactically valid as a final sanity check: `syntax OK`.
- [ ] Delete the manual test emails sent during Task 3 Steps 5/6 from Mailpit (test noise, not real digest history) — same cleanup as the base digest's plan.
- [ ] The day after deployment, confirm Task 3 Step 6 (real ntopng data present) actually ran and looked right — this is the one thing that could not be fully verified today.
