# vnstat Daily Digest Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `vnstat_digest.py`, a daily Mailpit email summarizing yesterday's and month-to-date network traffic on `enp5s0`, wired into the existing `every_24_hours.sh` chain.

**Architecture:** One self-contained script following the `docker_digest.py` / `loan_prepayment_digest.py` shape: pure parsing/derivation/HTML functions (unit-tested, plain-assert style) at the top, an impure `gather()`/`main()` orchestration layer at the bottom (shells out to `vnstat --json`, sends via `homelab.clients.mailpit`, not unit-tested — same convention as its siblings). Config via a `vnstat-digest.env` sidecar. Wired in with one line in `every_24_hours.sh`.

**Tech Stack:** Python 3 (`python-rsha` virtualenv), stdlib `subprocess`/`json`/`datetime`, `python-dotenv`, the local `homelab` package (`set_source`, `homelab.clients.mailpit`).

## Global Constraints

- Script shebang: `#!/home/madhur/.virtualenvs/python-rsha/bin/python` (matches every sibling digest).
- Config keys (from the spec): `MAIL_FROM` (default `vnstat-digest@madhur.co.in`), `MAIL_TO` (default `ahuja.madhur@gmail.com`), `VNSTAT_IFACE` (default `enp5s0`), `DAYS_TABLE` (default `7`).
- Units are binary (KiB/MiB/GiB/TiB, 1024-based), matching vnstat's own CLI — **not** decimal like the docker digest.
- "Yesterday" = `(now − 1 day)` in IST (`timezone(timedelta(hours=5, minutes=30))`), not "today", because the digest fires ~20:02 IST while today is still partial.
- No anomaly/threshold gating — this digest always sends (no `SEND_WHEN_EMPTY`-style toggle).
- `/home/madhur/scripts` is **not a git repository** (verified: `git status` → "not a git repository"). Skip every "Commit" step from the standard plan template — there is nothing to commit to. Each task ends with a verification run instead.
- Test convention (matching `tests/test_loan_prepayment_digest.py`): plain `assert`-based tests, a `run_test(name, fn)` PASS/FAIL runner, no pytest, run via `python3 tests/test_vnstat_digest.py`. Only pure functions are tested; `fetch_raw()`/`gather()`/`main()` (subprocess + network I/O) are verified manually, not via unit test.

---

## File Structure

- **Create:** `/home/madhur/scripts/vnstat_digest.py` — the script (parsing/derivation, email builders, orchestration, `main()`).
- **Create:** `/home/madhur/scripts/vnstat-digest.env` — config sidecar, committed with default values (matches `docker-digest.env`'s pattern of committing real defaults, not secrets — this file holds no secrets).
- **Create:** `/home/madhur/scripts/tests/test_vnstat_digest.py` — unit tests for the pure functions.
- **Modify:** `/home/madhur/scripts/every_24_hours.sh` — add one `run_with_notification` line.

---

### Task 1: Parsing & derivation core

**Files:**
- Create: `/home/madhur/scripts/vnstat_digest.py`
- Test: `/home/madhur/scripts/tests/test_vnstat_digest.py`

**Interfaces:**
- Produces: `extract_traffic(raw: dict, iface: str) -> dict` (raises `ValueError` if `iface` absent), `_to_date(d: dict) -> date`, `find_day(days: list[dict], target: date) -> dict | None`, `find_month(months: list[dict], year: int, month: int) -> dict | None`, `human(n: int) -> str`, `derive(traffic: dict, today: date, days_table: int) -> dict` (returns `{"yesterday": dict|None, "month": dict|None, "rows": list[dict]}`, each row `{"date": date, "rx": int, "tx": int, "total": int, "is_today": bool}`).

- [ ] **Step 1: Write the failing tests**

Create `/home/madhur/scripts/tests/test_vnstat_digest.py`:

```python
#!/usr/bin/env python3
"""Unit tests for vnstat_digest.py.

Plain assert-based tests, PASS/FAIL runner — same convention as
tests/test_loan_prepayment_digest.py. Run directly:
python3 ~/scripts/tests/test_vnstat_digest.py

Pure-logic functions only (extract_traffic, find_day, find_month, human,
derive, build_email) are tested here — no live vnstat/Mailpit calls.
Importing vnstat_digest is safe: its module-level code only loads .env
files and calls set_source(), no network calls until main() runs.
"""
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import vnstat_digest as vd

FAILURES = 0


def run_test(name, fn):
    global FAILURES
    try:
        fn()
        print(f"PASS: {name}")
    except AssertionError as e:
        print(f"FAIL: {name}: {e}")
        FAILURES += 1
    except Exception as e:
        print(f"FAIL: {name}: unexpected {type(e).__name__}: {e}")
        FAILURES += 1


# Fixture: a trimmed-down but real shape of `vnstat -i enp5s0 --json` output
# (captured 2026-08-09; rx/tx values match vnstat's own CLI "7.97 GiB" /
# "5.79 GiB" report for the 2026-08-08 day entry).
RAW_FIXTURE = {
    "vnstatversion": "2.13",
    "jsonversion": "2",
    "interfaces": [{
        "name": "enp5s0",
        "alias": "",
        "created": {"date": {"year": 2026, "month": 8, "day": 8}, "timestamp": 1786202930},
        "updated": {"date": {"year": 2026, "month": 8, "day": 9},
                    "time": {"hour": 15, "minute": 0}, "timestamp": 1786267800},
        "traffic": {
            "total": {"rx": 109096234491, "tx": 104894708838},
            "day": [
                {"id": 72, "date": {"year": 2026, "month": 8, "day": 8},
                 "timestamp": 1786127400, "rx": 8556681323, "tx": 6214523409},
                {"id": 158, "date": {"year": 2026, "month": 8, "day": 9},
                 "timestamp": 1786213800, "rx": 100539553168, "tx": 98680185429},
            ],
            "month": [
                {"id": 72, "date": {"year": 2026, "month": 8},
                 "timestamp": 1785522600, "rx": 109096234491, "tx": 104894708838},
            ],
        },
    }],
}


def test_extract_traffic_finds_matching_interface():
    traffic = vd.extract_traffic(RAW_FIXTURE, "enp5s0")
    assert traffic["total"]["rx"] == 109096234491


def test_extract_traffic_raises_when_interface_missing():
    try:
        vd.extract_traffic(RAW_FIXTURE, "eth9")
        assert False, "expected ValueError"
    except ValueError as e:
        assert "eth9" in str(e)
        assert "enp5s0" in str(e)


def test_find_day_matches_by_date():
    days = RAW_FIXTURE["interfaces"][0]["traffic"]["day"]
    entry = vd.find_day(days, date(2026, 8, 8))
    assert entry["rx"] == 8556681323


def test_find_day_returns_none_when_absent():
    days = RAW_FIXTURE["interfaces"][0]["traffic"]["day"]
    assert vd.find_day(days, date(2026, 1, 1)) is None


def test_find_month_matches_year_and_month():
    months = RAW_FIXTURE["interfaces"][0]["traffic"]["month"]
    entry = vd.find_month(months, 2026, 8)
    assert entry["rx"] == 109096234491


def test_find_month_returns_none_when_absent():
    months = RAW_FIXTURE["interfaces"][0]["traffic"]["month"]
    assert vd.find_month(months, 2025, 1) is None


def test_human_bytes():
    assert vd.human(0) == "0 B"
    assert vd.human(500) == "500 B"


def test_human_kib_mib_gib():
    assert vd.human(1024) == "1.00 KiB"
    assert vd.human(1024 * 1024) == "1.00 MiB"
    # Real fixture value: vnstat's own CLI reports this exact byte count as "7.97 GiB".
    assert vd.human(8556681323) == "7.97 GiB"


def test_derive_picks_yesterday_and_month_and_rows():
    traffic = vd.extract_traffic(RAW_FIXTURE, "enp5s0")
    result = vd.derive(traffic, today=date(2026, 8, 9), days_table=7)
    assert result["yesterday"]["rx"] == 8556681323
    assert result["month"]["rx"] == 109096234491
    assert len(result["rows"]) == 2
    assert result["rows"][0]["date"] == date(2026, 8, 9)  # most recent first
    assert result["rows"][0]["is_today"] is True
    assert result["rows"][1]["is_today"] is False
    assert result["rows"][0]["total"] == 100539553168 + 98680185429


def test_derive_limits_rows_to_days_table():
    traffic = vd.extract_traffic(RAW_FIXTURE, "enp5s0")
    result = vd.derive(traffic, today=date(2026, 8, 9), days_table=1)
    assert len(result["rows"]) == 1
    assert result["rows"][0]["date"] == date(2026, 8, 9)


def test_derive_yesterday_none_when_no_matching_day():
    traffic = vd.extract_traffic(RAW_FIXTURE, "enp5s0")
    result = vd.derive(traffic, today=date(2026, 1, 1), days_table=7)
    assert result["yesterday"] is None
    assert result["month"] is None


if __name__ == "__main__":
    run_test("extract_traffic finds matching interface", test_extract_traffic_finds_matching_interface)
    run_test("extract_traffic raises when interface missing", test_extract_traffic_raises_when_interface_missing)
    run_test("find_day matches by date", test_find_day_matches_by_date)
    run_test("find_day returns None when absent", test_find_day_returns_none_when_absent)
    run_test("find_month matches year and month", test_find_month_matches_year_and_month)
    run_test("find_month returns None when absent", test_find_month_returns_none_when_absent)
    run_test("human formats bytes", test_human_bytes)
    run_test("human formats KiB/MiB/GiB", test_human_kib_mib_gib)
    run_test("derive picks yesterday, month, and rows", test_derive_picks_yesterday_and_month_and_rows)
    run_test("derive limits rows to days_table", test_derive_limits_rows_to_days_table)
    run_test("derive yesterday is None when no matching day", test_derive_yesterday_none_when_no_matching_day)
    print(f"\n{FAILURES} failure(s)" if FAILURES else "\nAll tests passed")
    sys.exit(1 if FAILURES else 0)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 /home/madhur/scripts/tests/test_vnstat_digest.py`
Expected: `ModuleNotFoundError: No module named 'vnstat_digest'` (or import error) — the module doesn't exist yet.

- [ ] **Step 3: Write the minimal implementation**

Create `/home/madhur/scripts/vnstat_digest.py`:

```python
#!/home/madhur/.virtualenvs/python-rsha/bin/python
"""vnstat daily digest -> Mailpit.

Emails a snapshot of network traffic on the main NIC (`VNSTAT_IFACE`, default
enp5s0): yesterday's RX/TX/total, month-to-date total, and a table of the
last few days. "Yesterday" (not "today") is the headline because this fires
~20:02 IST via every_24_hours.sh, while today is still partial.

Sibling of the docker / firefly / bookstack / ccusage digests — same shape:
shared homelab Mailpit client (every send surfaces in Prometheus as
service=mailpit, source=vnstat_digest), a dark HTML template, and a
*-digest.env sidecar. Invoked daily from ~/scripts/every_24_hours.sh.

Units are binary (KiB/MiB/GiB), matching vnstat's own CLI output — unlike
the docker digest, which mirrors Docker's decimal units.

Config (override via vnstat-digest.env):
  MAIL_FROM    (default vnstat-digest@madhur.co.in)
  MAIL_TO      (default ahuja.madhur@gmail.com)
  VNSTAT_IFACE (default enp5s0)
  DAYS_TABLE   (default 7)
"""

from __future__ import annotations

import os
from datetime import date, timedelta, timezone
from pathlib import Path

from dotenv import load_dotenv

from homelab import set_source

set_source("vnstat_digest")

SCRIPT_DIR = Path(__file__).resolve().parent
load_dotenv(SCRIPT_DIR / "vnstat-digest.env")

MAIL_FROM = os.environ.get("MAIL_FROM", "vnstat-digest@madhur.co.in")
MAIL_TO = os.environ.get("MAIL_TO", "ahuja.madhur@gmail.com")
VNSTAT_IFACE = os.environ.get("VNSTAT_IFACE", "enp5s0")
DAYS_TABLE = int(os.environ.get("DAYS_TABLE", "7"))

IST = timezone(timedelta(hours=5, minutes=30))


# --------------------------------------------------------------------------- #
# Parsing / derivation (pure)
# --------------------------------------------------------------------------- #
def extract_traffic(raw: dict, iface: str) -> dict:
    """Pull the `traffic` node for `iface` out of `vnstat --json` output.

    Raises ValueError if the interface isn't present in vnstat's output."""
    for entry in raw.get("interfaces", []):
        if entry.get("name") == iface:
            return entry["traffic"]
    known = ", ".join(e.get("name", "?") for e in raw.get("interfaces", [])) or "none"
    raise ValueError(f"interface {iface!r} not found in vnstat output (known: {known})")


def _to_date(d: dict) -> date:
    return date(d["year"], d["month"], d.get("day", 1))


def find_day(days: list[dict], target: date) -> dict | None:
    """The `day` entry whose date matches `target`, or None."""
    for entry in days:
        if _to_date(entry["date"]) == target:
            return entry
    return None


def find_month(months: list[dict], year: int, month: int) -> dict | None:
    """The `month` entry matching (year, month), or None."""
    for entry in months:
        d = entry["date"]
        if d["year"] == year and d["month"] == month:
            return entry
    return None


def human(n: int) -> str:
    """Bytes -> binary-unit string matching vnstat's own CLI (e.g. '7.97 GiB')."""
    f = float(n)
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if f < 1024 or unit == "TiB":
            return f"{f:.0f} {unit}" if unit == "B" else f"{f:.2f} {unit}"
        f /= 1024
    return f"{f:.2f} TiB"


def derive(traffic: dict, today: date, days_table: int) -> dict:
    """Pure derivation from a `traffic` node: yesterday's entry, this
    month's entry, and the last `days_table` day-rows (most recent first,
    today's row flagged `is_today` if present and partial)."""
    days = traffic.get("day", [])
    months = traffic.get("month", [])

    yesterday_entry = find_day(days, today - timedelta(days=1))
    month_entry = find_month(months, today.year, today.month)

    rows = []
    for entry in sorted(days, key=lambda e: _to_date(e["date"]), reverse=True)[:days_table]:
        d = _to_date(entry["date"])
        rows.append({
            "date": d,
            "rx": entry["rx"],
            "tx": entry["tx"],
            "total": entry["rx"] + entry["tx"],
            "is_today": d == today,
        })

    return {"yesterday": yesterday_entry, "month": month_entry, "rows": rows}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 /home/madhur/scripts/tests/test_vnstat_digest.py`
Expected: `All tests passed` (11 PASS lines, 0 failures).

---

### Task 2: Email content builders

**Files:**
- Modify: `/home/madhur/scripts/vnstat_digest.py` (append)
- Modify: `/home/madhur/scripts/tests/test_vnstat_digest.py` (append)

**Interfaces:**
- Consumes: `human()` and the `derive()` result shape from Task 1 (`{"yesterday": dict|None, "month": dict|None, "rows": list[dict]}`).
- Produces: `build_email(d: dict) -> tuple[str, str, str]` — `d` is `{"iface": str, "now": date, "created": date, "yesterday": dict|None, "month": dict|None, "rows": list[dict]}`; returns `(subject, plain_body, html_body)`. Task 3's `gather()`/`main()` assemble `d` and call this.

- [ ] **Step 1: Write the failing tests**

Append to `/home/madhur/scripts/tests/test_vnstat_digest.py` (before the `if __name__ ==` block):

```python
def _email_ctx(**overrides):
    base = {
        "iface": "enp5s0",
        "now": date(2026, 8, 9),
        "created": date(2026, 8, 8),
        "yesterday": {"rx": 8556681323, "tx": 6214523409},
        "month": {"rx": 109096234491, "tx": 104894708838},
        "rows": [
            {"date": date(2026, 8, 9), "rx": 100539553168, "tx": 98680185429,
             "total": 100539553168 + 98680185429, "is_today": True},
            {"date": date(2026, 8, 8), "rx": 8556681323, "tx": 6214523409,
             "total": 8556681323 + 6214523409, "is_today": False},
        ],
    }
    base.update(overrides)
    return base


def test_build_email_subject_includes_iface_and_yesterday_totals():
    subject, plain, html = vd.build_email(_email_ctx())
    assert "enp5s0" in subject
    assert "7.97 GiB" in subject  # yesterday rx
    assert "5.79 GiB" in subject  # yesterday tx
    assert "08 Aug" in subject


def test_build_email_subject_no_data_when_yesterday_missing():
    subject, plain, html = vd.build_email(_email_ctx(yesterday=None))
    assert "no data for yesterday" in subject


def test_build_email_plain_includes_month_to_date():
    subject, plain, html = vd.build_email(_email_ctx())
    assert "7.97 GiB" in plain
    assert "Month-to-date" in plain
    assert "199.29 GiB" in plain  # month total: (109096234491+104894708838) bytes


def test_build_email_html_marks_today_row():
    subject, plain, html = vd.build_email(_email_ctx())
    assert "(so far)" in html
    assert "enp5s0" in html


def test_build_email_html_omits_today_marker_when_no_today_row():
    ctx = _email_ctx(rows=[
        {"date": date(2026, 8, 8), "rx": 8556681323, "tx": 6214523409,
         "total": 8556681323 + 6214523409, "is_today": False},
    ])
    _, _, html = vd.build_email(ctx)
    assert "(so far)" not in html
```

And extend the `if __name__ ==` runner block with these five `run_test(...)` calls (keep the existing ones above them, keep the summary/exit lines last).

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 /home/madhur/scripts/tests/test_vnstat_digest.py`
Expected: `FAIL: ... AttributeError: module 'vnstat_digest' has no attribute 'build_email'` for the 5 new tests; the 11 Task-1 tests still PASS.

- [ ] **Step 3: Write the minimal implementation**

Append to `/home/madhur/scripts/vnstat_digest.py`:

```python
# --------------------------------------------------------------------------- #
# Email content (pure)
# --------------------------------------------------------------------------- #
def _esc(s) -> str:
    import html as _html
    return _html.escape(str(s))


def _stat(label: str, value: str, accent: str = "#e8eaed") -> str:
    return (
        '<td style="padding:10px 16px;background:#232427;border-radius:8px;text-align:center">'
        f'<div style="color:#9aa0a6;font-size:11px;text-transform:uppercase;letter-spacing:.5px">{label}</div>'
        f'<div style="color:{accent};font-size:22px;font-weight:600;margin-top:4px">{value}</div></td>'
    )


def _cell(text: str, align: str = "left", color: str = "") -> str:
    style = f"padding:6px 12px;border-bottom:1px solid #2c2e33;text-align:{align}"
    if color:
        style += f";color:{color}"
    return f'<td style="{style}">{text}</td>'


def _table(title: str, headers: list[tuple[str, str]], rows: list[str]) -> str:
    if not rows:
        return ""
    head = "".join(
        f'<th style="text-align:{align};padding:6px 12px;color:#9aa0a6;font-weight:500">{_esc(label)}</th>'
        for label, align in headers
    )
    return (
        f'<h3 style="margin:24px 0 6px;color:#e8eaed;font-size:15px">{title}</h3>'
        '<table style="width:100%;border-collapse:collapse;font-size:13px">'
        f"<tr>{head}</tr>" + "".join(rows) + "</table>"
    )


def build_email(d: dict) -> tuple[str, str, str]:
    """d: {iface, now(date), created(date), yesterday(dict|None),
    month(dict|None), rows(list[dict])} -> (subject, plain_body, html_body)."""
    iface = d["iface"]
    yesterday = d["yesterday"]
    month = d["month"]

    if yesterday:
        y_label = (d["now"] - timedelta(days=1)).strftime("%d %b")
        subject = (f'vnstat — {iface} — {human(yesterday["rx"])} ↓ / '
                   f'{human(yesterday["tx"])} ↑ yesterday ({y_label})')
        plain = (f'Yesterday: {human(yesterday["rx"])} down / {human(yesterday["tx"])} up '
                 f'({human(yesterday["rx"] + yesterday["tx"])} total) on {iface}.')
    else:
        subject = f'vnstat — {iface} — no data for yesterday yet'
        plain = f'No vnstat data for yesterday on {iface} yet.'

    if month:
        m_total = month["rx"] + month["tx"]
        plain += f' Month-to-date: {human(m_total)} total.'

    headline = '<table style="border-spacing:10px 0;width:100%"><tr>'
    if yesterday:
        headline += (
            _stat("Yesterday RX", human(yesterday["rx"]), "#6cb6ff")
            + _stat("Yesterday TX", human(yesterday["tx"]), "#6cb6ff")
            + _stat("Yesterday Total", human(yesterday["rx"] + yesterday["tx"]), "#81c995")
        )
    else:
        headline += _stat("Yesterday", "no data", "#9aa0a6")
    headline += (_stat("Month-to-date", human(month["rx"] + month["tx"]), "#f5b942")
                 if month else _stat("Month-to-date", "no data", "#9aa0a6"))
    headline += "</tr></table>"

    row_html = [
        f'<tr>{_cell(_esc(r["date"].strftime("%a %d %b")) + (" (so far)" if r["is_today"] else ""))}'
        f'{_cell(human(r["rx"]), "right")}{_cell(human(r["tx"]), "right")}'
        f'{_cell(human(r["total"]), "right", "#81c995")}</tr>'
        for r in d["rows"]
    ]
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

    return subject, plain, html
```

Note: `_esc` is defined with a local `import html as _html` (rather than a top-level `import html`) to avoid shadowing the `html` variable name used for the returned HTML string body throughout this function and Task 3's `main()`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 /home/madhur/scripts/tests/test_vnstat_digest.py`
Expected: `All tests passed` (16 PASS lines, 0 failures).

---

### Task 3: vnstat fetch + orchestration (`gather`, `main`)

**Files:**
- Modify: `/home/madhur/scripts/vnstat_digest.py` (append; no new automated tests — this task is subprocess/network I/O, verified manually per Step 3 below, matching how `docker_digest.py`'s `gather()`/`main()` and `loan_prepayment_digest.py`'s `main()` are handled)

**Interfaces:**
- Consumes: `extract_traffic`, `derive`, `build_email`, `_to_date` (Tasks 1–2); `homelab.clients.mailpit.push(subject, *, sender, body, html, recipient) -> bool` (existing, read in design phase).
- Produces: `fetch_raw(iface: str) -> dict`, `gather(iface: str, days_table: int) -> dict`, `main() -> int`.

- [ ] **Step 1: Write the implementation**

Append to `/home/madhur/scripts/vnstat_digest.py` (top of file also needs the extra imports below — add them to the existing `import` block at the top, don't duplicate):

Add to the top-of-file imports (edit the existing block from Task 1 to include these):
```python
import json
import subprocess
import sys
from datetime import datetime  # (date, timedelta, timezone already imported)

from homelab.clients import mailpit
```

Then append at the end of the file:

```python
# --------------------------------------------------------------------------- #
# vnstat call + orchestration
# --------------------------------------------------------------------------- #
def fetch_raw(iface: str) -> dict:
    """Run `vnstat -i <iface> --json` and parse its stdout."""
    out = subprocess.run(
        ["vnstat", "-i", iface, "--json"],
        capture_output=True, text=True, check=True,
    ).stdout
    return json.loads(out)


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


def main() -> int:
    try:
        d = gather(VNSTAT_IFACE, DAYS_TABLE)
    except FileNotFoundError:
        print("ERROR: vnstat CLI not found", file=sys.stderr)
        return 1
    except subprocess.CalledProcessError as e:
        # vnstat writes its "no such interface" message to stdout, not stderr.
        detail = (e.stderr or e.stdout or str(e)).strip()
        print(f"ERROR: vnstat command failed: {detail}", file=sys.stderr)
        return 1
    except (ValueError, json.JSONDecodeError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

    subject, plain, html = build_email(d)

    ok = mailpit.push(
        subject,
        sender=f"vnstat Digest <{MAIL_FROM}>",
        body=plain,
        html=html,
        recipient=MAIL_TO,
    )
    if not ok:
        print("ERROR: Mailpit send failed", file=sys.stderr)
        return 1

    print(f"Sent vnstat digest -> {MAIL_TO} ({subject})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run the existing unit tests to confirm nothing broke**

Run: `python3 /home/madhur/scripts/tests/test_vnstat_digest.py`
Expected: `All tests passed` (16 PASS lines — importing the module now also imports `subprocess`/`mailpit`, but doesn't call them at import time, so this must still pass with no network access).

- [ ] **Step 3: Make the script executable and do a manual live run**

```bash
chmod +x /home/madhur/scripts/vnstat_digest.py
/home/madhur/scripts/vnstat_digest.py; echo "exit=$?"
```

Expected: prints `Sent vnstat digest -> ahuja.madhur@gmail.com (vnstat — enp5s0 — ...)` and `exit=0`. Then open Mailpit's web UI and confirm the message arrived with sane numbers matching `vnstat -i enp5s0`'s own terminal output (headline stats, days table, footer).

- [ ] **Step 4: Verify the error path with a bad interface name**

`VNSTAT_IFACE` is read from the environment at module import time, so a plain env-var prefix on the same script invocation is enough — no need to re-import or reload anything:

```bash
VNSTAT_IFACE=nonexistent0 /home/madhur/scripts/vnstat_digest.py; echo "exit=$?"
```

Expected: `exit=1`, and **no** new message in Mailpit. Note: `vnstat` itself rejects an unmonitored interface before we ever see its JSON (it exits 1 with `Error: No interface matching "nonexistent0" found in database.` on stdout), so this hits the `subprocess.CalledProcessError` branch rather than `extract_traffic`'s `ValueError` — expected stderr is `ERROR: vnstat command failed: Error: No interface matching "nonexistent0" found in database.`. (`extract_traffic`'s own not-found message is still reachable — e.g. if `VNSTAT_IFACE` names an interface vnstat monitors under a different alias than expected — and is covered by Task 1's unit test.)

---

### Task 4: Config file + wiring into `every_24_hours.sh`

**Files:**
- Create: `/home/madhur/scripts/vnstat-digest.env`
- Modify: `/home/madhur/scripts/every_24_hours.sh`

**Interfaces:**
- Consumes: `vnstat_digest.py`'s `MAIL_FROM`/`MAIL_TO`/`VNSTAT_IFACE`/`DAYS_TABLE` env-var reads (Task 1); `run_with_notification` (existing shell function, sourced from `notify_wrapper.sh` at the top of `every_24_hours.sh`).
- Produces: nothing consumed by later tasks — this is the last task.

- [ ] **Step 1: Create the env file**

Create `/home/madhur/scripts/vnstat-digest.env`:

```
# vnstat daily digest config (loaded by vnstat_digest.py).
# All keys are optional; the defaults below match the committed values.

MAIL_FROM=vnstat-digest@madhur.co.in
MAIL_TO=ahuja.madhur@gmail.com

# Interface to report on. enp5s0 is the only physical NIC on this box —
# everything else under `ip link` is a docker bridge or veth pair.
VNSTAT_IFACE=enp5s0

# Rows to show in the "last N days" table.
DAYS_TABLE=7
```

- [ ] **Step 2: Wire it into the daily chain**

Read `/home/madhur/scripts/every_24_hours.sh` and add this line directly after the existing `docker_digest.py` line (both are "→ Mailpit" monitoring digests, so they stay grouped):

```bash
run_with_notification "/home/madhur/scripts/vnstat_digest.py" "vnstat Daily Digest → Mailpit" "monitoring"
```

- [ ] **Step 3: Verify the env file is picked up**

```bash
cd /home/madhur/scripts && DAYS_TABLE=2 /home/madhur/scripts/vnstat_digest.py; echo "exit=$?"
```

Expected: `exit=0`, and the Mailpit message's days table shows exactly 2 rows (confirms env-var override works; the committed file's default of 7 will apply on the real daily run).

- [ ] **Step 4: Verify the shell wiring syntax**

```bash
bash -n /home/madhur/scripts/every_24_hours.sh && echo "syntax OK"
```

Expected: `syntax OK` (no bash syntax errors introduced by the added line).

---

## Post-Plan Verification (do once, after all tasks)

- [ ] Re-run `python3 /home/madhur/scripts/tests/test_vnstat_digest.py` one final time — `All tests passed`.
- [ ] Confirm `crontab`-equivalent (the `every24hours.timer` systemd user timer) needs no changes — it already fires `every_24_hours.sh` daily (~20:02 IST); the new line rides along automatically. Check with `systemctl --user list-timers every24hours.timer`.
- [ ] Check Mailpit for the two manual test sends from Task 3/4 — safe to delete them from Mailpit's UI since they're test noise, not real digest history.
