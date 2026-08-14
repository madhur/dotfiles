# vnstat Digest — Per-Device Application Breakdown Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the flat "Top applications" table in the vnstat digest with a nested "Top applications by device" breakdown — for each of the top devices, its own top apps.

**Architecture:** Factor the local-device attribution logic out of `top_talkers` into a small reusable `local_device_labels(flow)` helper (safe refactor — existing `top_talkers` tests are the regression check). Add `device_app_breakdown(flows, device_label)`, which filters flows to one device's local-side traffic and reuses the *existing* `top_apps()` to aggregate — no duplicated aggregation logic. `gather_ntopng()` swaps its flat `"apps"` key for a `"by_device"` dict; rendering replaces the flat table with a nested per-device section.

**Tech Stack:** Same as the base digest and its enrichment — pure Python, no new dependencies.

## Global Constraints

- All changes land in the existing `/home/madhur/scripts/vnstat_digest.py`, `/home/madhur/scripts/tests/test_vnstat_digest.py`, and `/home/madhur/scripts/vnstat-digest.env` — no new files.
- `device_app_breakdown` returns the **full, untruncated, descending-sorted** list, same contract as `top_talkers`/`top_apps` — truncation to `APPS_PER_DEVICE` happens at render time in `build_email`, not in the aggregator.
- `top_apps()` is **not deleted** — it's reused as-is by `device_app_breakdown` (called on a device-filtered flow subset). Its existing tests stay unchanged and still pass.
- The flat "Top applications" table and its `_ntopng_ctx()["apps"]`/`build_email` assertions are removed — replaced by the nested section's own tests. `ntopng["apps"]` is no longer a key `gather_ntopng()` produces.
- Same test convention throughout: plain `assert`-based tests, `run_test(name, fn)` PASS/FAIL runner in `tests/test_vnstat_digest.py`, run via `python3 tests/test_vnstat_digest.py`. `gather_ntopng()`'s subprocess call is still not unit-tested (unchanged from the enrichment plan).
- `/home/madhur/scripts` is **not a git repository** — no "Commit" steps; each task ends with a verification run instead.
- Live-confirmed today: the flow journal still has no data for "yesterday" (2026-08-08) — a real live run of the updated digest will still hit the `gather_ntopng()` no-data path and send without either ntopng section. Manual verification of the new nested section's actual rendering uses a synthetic sample send (same approach as the earlier ntopng-enrichment preview), not a live "yesterday" run.

---

## File Structure

- **Modify:** `/home/madhur/scripts/vnstat_digest.py` — add `local_device_labels`; refactor `top_talkers` to use it; add `device_app_breakdown`; change `gather_ntopng()` to build `by_device` instead of `apps`; replace `_ntopng_tables()`'s flat-apps rendering with a nested per-device section; add `APPS_PER_DEVICE` config; update docstrings.
- **Modify:** `/home/madhur/scripts/tests/test_vnstat_digest.py` — add tests for `local_device_labels`/`device_app_breakdown`; replace the flat-apps `build_email` tests with nested-section tests.
- **Modify:** `/home/madhur/scripts/vnstat-digest.env` — add `APPS_PER_DEVICE=3`.

---

### Task 1: `local_device_labels` refactor + `device_app_breakdown`

**Files:**
- Modify: `/home/madhur/scripts/vnstat_digest.py`
- Modify: `/home/madhur/scripts/tests/test_vnstat_digest.py`

**Interfaces:**
- Consumes: `top_apps(flows)` (existing, unchanged) as the aggregator `device_app_breakdown` delegates to.
- Produces: `local_device_labels(f: dict) -> list[str]` (0, 1, or 2 labels — 2 only for a local↔local flow). `device_app_breakdown(flows: list[dict], device_label: str) -> list[dict]` — same `[{"label": str, "bytes": int}, ...]` full/untruncated shape as `top_talkers`/`top_apps`. `top_talkers`'s public signature and behavior are unchanged (internal refactor only) — Task 2's `gather_ntopng()` still calls it exactly as before.

- [ ] **Step 1: Write the failing tests**

Add to `/home/madhur/scripts/tests/test_vnstat_digest.py`, directly after the `FLOW_FIXTURE` block and before `test_parse_flow_lines_skips_non_json_and_blank_lines`:

```python
def test_local_device_labels_covers_all_directions():
    assert vd.local_device_labels(FLOW_FIXTURE[0]) == ["kafka"]  # local -> remote
    assert vd.local_device_labels(FLOW_FIXTURE[1]) == ["Mac"]    # remote -> local
    assert vd.local_device_labels(FLOW_FIXTURE[2]) == ["kafka", "router"]  # local <-> local
    assert vd.local_device_labels({"SRC_ADDR_LOCAL": False, "DST_ADDR_LOCAL": False}) == []
```

And after `test_top_talkers_and_top_apps_return_empty_list_for_no_flows`:

```python
def test_device_app_breakdown_filters_to_one_device_and_ranks():
    # kafka's own flows from FLOW_FIXTURE: flow 1 (TLS, 1000), flow 3
    # (HTTP.SOAP, 200, local<->local so kafka is one of its two endpoints),
    # flow 5 (missing L7_PROTO_NAME -> Unknown, 20).
    result = vd.device_app_breakdown(FLOW_FIXTURE, "kafka")
    assert result == [
        {"label": "TLS", "bytes": 1000},
        {"label": "HTTP.SOAP", "bytes": 200},
        {"label": "Unknown", "bytes": 20},
    ]


def test_device_app_breakdown_returns_empty_for_unmatched_device():
    assert vd.device_app_breakdown(FLOW_FIXTURE, "nonexistent-device") == []
```

Then extend the `if __name__ ==` runner block — add the first new call right after the existing `run_test("top_talkers falls back to IP when name unresolved", ...)` line's group is fine anywhere, but for readability add all 3 new calls together right after `run_test("top_talkers and top_apps return empty list for no flows", test_top_talkers_and_top_apps_return_empty_list_for_no_flows)`:

```python
    run_test("local_device_labels covers all directions", test_local_device_labels_covers_all_directions)
    run_test("device_app_breakdown filters to one device and ranks", test_device_app_breakdown_filters_to_one_device_and_ranks)
    run_test("device_app_breakdown returns empty for unmatched device", test_device_app_breakdown_returns_empty_for_unmatched_device)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `/home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/scripts/tests/test_vnstat_digest.py`
Expected: the 3 new tests `FAIL` with `AttributeError: module 'vnstat_digest' has no attribute 'local_device_labels'` (and similarly for `device_app_breakdown`); all 24 existing tests still `PASS`.

- [ ] **Step 3: Write the minimal implementation**

In `/home/madhur/scripts/vnstat_digest.py`, replace the `top_talkers` function:

```python
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
```

with:

```python
def local_device_labels(f: dict) -> list[str]:
    """The local-device label(s) a flow attributes to: SRC_NAME/
    IPV4_SRC_ADDR if the source is local, DST_NAME/IPV4_DST_ADDR if the
    destination is local — both, for a local<->local flow (both devices
    genuinely participated); neither if the flow doesn't touch a local
    address at all."""
    labels = []
    if f.get("SRC_ADDR_LOCAL"):
        labels.append(f.get("SRC_NAME") or f.get("IPV4_SRC_ADDR", "?"))
    if f.get("DST_ADDR_LOCAL"):
        labels.append(f.get("DST_NAME") or f.get("IPV4_DST_ADDR", "?"))
    return labels


def top_talkers(flows: list[dict]) -> list[dict]:
    """Total bytes per local device, summed across every flow it appears in
    as a local endpoint (see local_device_labels). Returns the full list
    sorted descending by bytes — NOT truncated; truncation to TOP_N happens
    at render time in build_email."""
    totals: dict[str, int] = {}
    for f in flows:
        total = f.get("IN_BYTES", 0) + f.get("OUT_BYTES", 0)
        for label in local_device_labels(f):
            totals[label] = totals.get(label, 0) + total
    ranked = sorted(totals.items(), key=lambda kv: kv[1], reverse=True)
    return [{"label": k, "bytes": v} for k, v in ranked]
```

Then add `device_app_breakdown` directly after `top_apps()` (before the `# Email content (pure)` section header):

```python
def device_app_breakdown(flows: list[dict], device_label: str) -> list[dict]:
    """Apps used by one local device, ranked descending — the flows where
    `device_label` is a local endpoint (via local_device_labels), aggregated
    with the existing top_apps(). Full/untruncated, same render-time-
    truncation contract as top_talkers/top_apps."""
    matching = [f for f in flows if device_label in local_device_labels(f)]
    return top_apps(matching)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `/home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/scripts/tests/test_vnstat_digest.py`
Expected: `All tests passed` (27 PASS lines, 0 failures) — this includes the *unmodified* `top_talkers` tests still passing, confirming the refactor didn't change behavior.

---

### Task 2: Nested rendering + `gather_ntopng` swap

**Files:**
- Modify: `/home/madhur/scripts/vnstat_digest.py`
- Modify: `/home/madhur/scripts/tests/test_vnstat_digest.py`

**Interfaces:**
- Consumes: `device_app_breakdown` (Task 1); `top_talkers` (unchanged); `human`, `_esc`, `_cell`, `_table` (existing).
- Produces: `_ntopng_tables(ntopng, top_n, apps_per_device)` — signature grows the `apps_per_device` parameter. `gather_ntopng()`'s return shape changes from `{"talkers": ..., "apps": ...}` to `{"talkers": ..., "by_device": ...}` (Task 3 wires the real `apps_per_device` value through `build_email`'s `d.get("apps_per_device", 3)`).

- [ ] **Step 1: Write the failing tests**

In `/home/madhur/scripts/tests/test_vnstat_digest.py`, replace the `_ntopng_ctx()` fixture and its three dependent tests:

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

with:

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
        "by_device": {
            "kafka": [
                {"label": "TLS", "bytes": 900_000_000},
                {"label": "QUIC", "bytes": 400_000_000},
                {"label": "BitTorrent", "bytes": 300_000_000},
                {"label": "DNS", "bytes": 100_000_000},
            ],
            "Mac": [
                {"label": "TLS", "bytes": 1_000_000_000},
                {"label": "QUIC", "bytes": 400_000_000},
            ],
            "router": [
                {"label": "HTTP.SOAP", "bytes": 300_000_000},
            ],
        },
    }


def test_build_email_renders_ntopng_tables_when_present():
    ctx = _email_ctx(ntopng=_ntopng_ctx(), top_n=3, apps_per_device=2)
    _, _, html = vd.build_email(ctx)
    assert "Top devices (yesterday)" in html
    assert "kafka" in html
    assert "Top applications by device (yesterday)" in html
    # apps_per_device=2 shows kafka's TLS/QUIC, hides BitTorrent+DNS (400M) -> note
    assert "TLS" in html
    assert "QUIC" in html
    # kafka's BitTorrent(300M)+DNS(100M) truncated by apps_per_device=2 ->
    # human(400_000_000) = "381.47 MiB" (binary units, not a round decimal MB).
    assert "+2 more, totalling 381.47 MiB" in html
    assert "router" in html
    assert "HTTP.SOAP" in html
    # Mac (2 apps) and router (1 app) are both within apps_per_device=2 -> no
    # per-device note for either. Exactly 2 "more, totalling" notes total:
    # the devices table's own (+2 more, totalling 150 B, from top_n=3) and
    # kafka's app note above — confirms Mac/router don't add a spurious 3rd.
    assert html.count("more, totalling") == 2


def test_build_email_omits_ntopng_tables_when_absent():
    ctx = _email_ctx()  # no "ntopng" key at all -> build_email must default via .get()
    _, _, html = vd.build_email(ctx)
    assert "Top devices" not in html
    assert "Top applications by device" not in html


def test_build_email_omits_ntopng_tables_when_none():
    ctx = _email_ctx(ntopng=None)
    _, _, html = vd.build_email(ctx)
    assert "Top devices" not in html
    assert "Top applications by device" not in html
```

(`run_test(...)` calls for these three don't change — same names, same lines already in the runner block from the enrichment plan.)

- [ ] **Step 2: Run the tests to verify they fail**

Run: `/home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/scripts/tests/test_vnstat_digest.py`
Expected: `test_build_email_renders_ntopng_tables_when_present` `FAIL`s (looks for "Top applications by device (yesterday)", which doesn't render yet — still the old flat-table code); the two "omits" tests still `PASS` (nothing renders either way); all Task 1 tests still `PASS`.

- [ ] **Step 3: Write the minimal implementation**

In `/home/madhur/scripts/vnstat_digest.py`, replace `_ntopng_tables()`:

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

with:

```python
def _ntopng_tables(ntopng: dict | None, top_n: int, apps_per_device: int) -> str:
    """Render the top-devices table and the nested top-applications-by-
    device breakdown from gather_ntopng()'s full (untruncated) data. Returns
    "" when `ntopng` is None — enrichment unavailable or no flow data for
    yesterday."""
    if not ntopng:
        return ""

    talkers = ntopng["talkers"]
    shown, rest = talkers[:top_n], talkers[top_n:]
    row_html = [
        f'<tr>{_cell(_esc(r["label"]))}{_cell(human(r["bytes"]), "right")}</tr>'
        for r in shown
    ]
    devices_note = (f'+{len(rest)} more, totalling {human(sum(r["bytes"] for r in rest))}.'
                     if rest else "")
    devices_table = _table("Top devices (yesterday)",
                            [("Device", "left"), ("Traffic", "right")], row_html, note=devices_note)

    by_device = ntopng["by_device"]
    device_blocks = []
    for dev in shown:
        label = dev["label"]
        apps = by_device.get(label, [])
        shown_apps, rest_apps = apps[:apps_per_device], apps[apps_per_device:]
        app_rows = "".join(
            f'<tr>{_cell(_esc(a["label"]))}{_cell(human(a["bytes"]), "right")}</tr>'
            for a in shown_apps
        )
        app_note = (f'<p style="color:#5f6571;font-size:11px;margin:2px 0 0 12px">'
                    f'+{len(rest_apps)} more, totalling '
                    f'{human(sum(a["bytes"] for a in rest_apps))}.</p>'
                    if rest_apps else "")
        if not app_rows:
            continue
        device_blocks.append(
            f'<div style="margin-top:10px">'
            f'<div style="color:#e8eaed;font-size:13px;font-weight:600">{_esc(label)} '
            f'<span style="color:#9aa0a6;font-weight:400">— {human(dev["bytes"])}</span></div>'
            f'<table style="width:calc(100% - 12px);border-collapse:collapse;font-size:12px;margin:2px 0 0 12px">'
            f'{app_rows}</table>{app_note}</div>'
        )

    apps_section = ""
    if device_blocks:
        apps_section = (
            '<h3 style="margin:24px 0 6px;color:#e8eaed;font-size:15px">'
            'Top applications by device (yesterday)</h3>' + "".join(device_blocks)
        )

    return devices_table + apps_section
```

Then update `gather_ntopng()` — change:

```python
    return {"talkers": top_talkers(flows), "apps": top_apps(flows)}
```

to:

```python
    talkers = top_talkers(flows)
    by_device = {t["label"]: device_app_breakdown(flows, t["label"]) for t in talkers}
    return {"talkers": talkers, "by_device": by_device}
```

Update `build_email()`'s docstring and call site — change:

```python
def build_email(d: dict) -> tuple[str, str, str]:
    """d: {iface, now(date), created(date), yesterday(dict|None),
    month(dict|None), rows(list[dict]), ntopng(dict|None, optional, default
    None via .get()), top_n(int, optional, default 5 via .get())}
    -> (subject, plain_body, html_body)."""
```

to:

```python
def build_email(d: dict) -> tuple[str, str, str]:
    """d: {iface, now(date), created(date), yesterday(dict|None),
    month(dict|None), rows(list[dict]), ntopng(dict|None, optional, default
    None via .get()), top_n(int, optional, default 5 via .get()),
    apps_per_device(int, optional, default 3 via .get())}
    -> (subject, plain_body, html_body)."""
```

and change:

```python
    ntopng_tables = _ntopng_tables(d.get("ntopng"), d.get("top_n", 5))
```

to:

```python
    ntopng_tables = _ntopng_tables(d.get("ntopng"), d.get("top_n", 5), d.get("apps_per_device", 3))
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `/home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/scripts/tests/test_vnstat_digest.py`
Expected: `All tests passed` (27 PASS lines, 0 failures — same count as Task 1's end state, since this task replaced 3 existing tests rather than adding new ones).

---

### Task 3: `APPS_PER_DEVICE` config, wiring, and verification

**Files:**
- Modify: `/home/madhur/scripts/vnstat_digest.py`
- Modify: `/home/madhur/scripts/vnstat-digest.env`

**Interfaces:**
- Consumes: `gather_ntopng`, `_ntopng_tables`/`build_email`'s `apps_per_device` param (Task 2).
- Produces: nothing consumed by later tasks — this is the last task.

- [ ] **Step 1: Add the config constant**

In `/home/madhur/scripts/vnstat_digest.py`, change:

```python
DAYS_TABLE = int(os.environ.get("DAYS_TABLE", "7"))
TOP_N = int(os.environ.get("TOP_N", "5"))
```

to:

```python
DAYS_TABLE = int(os.environ.get("DAYS_TABLE", "7"))
TOP_N = int(os.environ.get("TOP_N", "5"))
APPS_PER_DEVICE = int(os.environ.get("APPS_PER_DEVICE", "3"))
```

Update the module docstring's Config list — change:

```
  TOP_N        (default 5) — rows in the ntopng top-devices/top-apps tables
```

to:

```
  TOP_N            (default 5) — rows in the "Top devices" table
  APPS_PER_DEVICE  (default 3) — apps shown per device in the nested
                   "Top applications by device" breakdown
```

- [ ] **Step 2: Wire it through `gather()` and `main()`**

Change:

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

to:

```python
def gather(iface: str, days_table: int, top_n: int, apps_per_device: int) -> dict:
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
        "apps_per_device": apps_per_device,
        **derived,
    }
```

And change `main()`'s call site:

```python
        d = gather(VNSTAT_IFACE, DAYS_TABLE, TOP_N)
```

to:

```python
        d = gather(VNSTAT_IFACE, DAYS_TABLE, TOP_N, APPS_PER_DEVICE)
```

- [ ] **Step 3: Add `APPS_PER_DEVICE` to the env file**

In `/home/madhur/scripts/vnstat-digest.env`, add after the `TOP_N=5` line:

```
# Apps shown per device in the "Top applications by device" breakdown.
APPS_PER_DEVICE=3
```

- [ ] **Step 4: Run the full test suite**

Run: `/home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/scripts/tests/test_vnstat_digest.py`
Expected: `All tests passed` (27/27).

- [ ] **Step 5: Live run — confirm the real (still no-data) path is unaffected**

```bash
/home/madhur/scripts/vnstat_digest.py; echo "exit=$?"
```

Expected: same as before this plan — `WARNING: ntopng enrichment skipped: no flows for yesterday` on stderr, `exit=0`, digest sent with neither ntopng section (confirms this change is inert until real "yesterday" flow data exists — nothing regressed for today's actual send). Delete this test email from Mailpit afterward (test noise).

- [ ] **Step 6: Manual sample send — verify the nested breakdown actually renders**

"Yesterday" has no data yet, so build a preview the same way as the earlier ntopng-enrichment sample — real vnstat data, real last-hour flow data standing in for "yesterday", subject prefixed `[SAMPLE]`:

```bash
/home/madhur/.virtualenvs/python-rsha/bin/python -c "
import vnstat_digest as vd
from homelab.clients import mailpit

d = vd.gather(vd.VNSTAT_IFACE, vd.DAYS_TABLE, vd.TOP_N, vd.APPS_PER_DEVICE)

lines = vd.fetch_flow_lines('-1h', 'now')
flows = vd.parse_flow_lines(lines)
talkers = vd.top_talkers(flows)
d['ntopng'] = {
    'talkers': talkers,
    'by_device': {t['label']: vd.device_app_breakdown(flows, t['label']) for t in talkers},
}

subject, plain, html = vd.build_email(d)
subject = '[SAMPLE] ' + subject + ' (ntopng section = last 1h, not a real yesterday)'

ok = mailpit.push(subject, sender=f'vnstat Digest <{vd.MAIL_FROM}>', body=plain, html=html, recipient=vd.MAIL_TO)
print('sent:', ok, '|', subject)
"
```

Expected: `sent: True`. Open the message in Mailpit (`https://mail.desktop.madhur.co.in`) and confirm: a "Top devices (yesterday)" table (unchanged from before), followed by a "Top applications by device (yesterday)" section with one heading + mini-table per top device, each showing up to `APPS_PER_DEVICE` apps and a "+k more" note where a device has more. No flat "Top applications" table should appear anywhere. Leave this sample for the user to inspect, or delete it via the Mailpit API if asked (same DELETE approach used for prior test sends).

---

## Post-Plan Verification (do once, after all tasks)

- [ ] Re-run `/home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/scripts/tests/test_vnstat_digest.py` one final time — `All tests passed` (27/27).
- [ ] `bash -n /home/madhur/scripts/every_24_hours.sh` — unaffected by this plan, final sanity check: `syntax OK`.
- [ ] The day after the flow journal has a genuine full "yesterday" (same caveat as the enrichment plan's Task 3 Step 6), confirm the real digest send shows sensible per-device app breakdowns, not just the synthetic sample.
