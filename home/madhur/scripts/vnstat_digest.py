#!/home/madhur/.virtualenvs/python-rsha/bin/python
"""vnstat daily digest -> Mailpit.

Emails a snapshot of network traffic on the main NIC (`VNSTAT_IFACE`, default
enp5s0): yesterday's RX/TX/total, and a day-by-day table for the month so
far (month-to-date, with a totals row). "Yesterday" (not "today") is the
headline because this fires ~20:02 IST via every_24_hours.sh, while today
is still partial.

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
  TOP_N        (default 5) — rows in the "Top devices" table

ntopng enrichment (top devices by traffic) reads the `ntopng-flows` journald
namespace via `sudo -n journalctl`. If that command fails or has no data for
yesterday, the table is silently omitted — this digest's core vnstat numbers
never depend on ntopng being present.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

from dotenv import load_dotenv

from homelab import set_source
from homelab.clients import mailpit

set_source("vnstat_digest")

SCRIPT_DIR = Path(__file__).resolve().parent
load_dotenv(SCRIPT_DIR / "vnstat-digest.env")

MAIL_FROM = os.environ.get("MAIL_FROM", "vnstat-digest@madhur.co.in")
MAIL_TO = os.environ.get("MAIL_TO", "ahuja.madhur@gmail.com")
VNSTAT_IFACE = os.environ.get("VNSTAT_IFACE", "enp5s0")
TOP_N = int(os.environ.get("TOP_N", "5"))

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


def derive(traffic: dict, today: date) -> dict:
    """Pure derivation from a `traffic` node: yesterday's entry, this
    month's entry, and every day-row for the current month so far (month-
    to-date, most recent first, today's row flagged `is_today` if present
    and partial)."""
    days = traffic.get("day", [])
    months = traffic.get("month", [])

    yesterday_entry = find_day(days, today - timedelta(days=1))
    month_entry = find_month(months, today.year, today.month)

    month_days = [
        entry for entry in days
        if _to_date(entry["date"]).year == today.year
        and _to_date(entry["date"]).month == today.month
    ]

    rows = []
    for entry in sorted(month_days, key=lambda e: _to_date(e["date"]), reverse=True):
        d = _to_date(entry["date"])
        rows.append({
            "date": d,
            "rx": entry["rx"],
            "tx": entry["tx"],
            "total": entry["rx"] + entry["tx"],
            "is_today": d == today,
        })

    return {"yesterday": yesterday_entry, "month": month_entry, "rows": rows}


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


def _ntopng_tables(ntopng: dict | None, top_n: int) -> str:
    """Render the top-devices table from gather_ntopng()'s full
    (untruncated) data. Returns "" when `ntopng` is None — enrichment
    unavailable or no flow data for yesterday."""
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
    return _table("Top devices (yesterday)",
                  [("Device", "left"), ("Traffic", "right")], row_html, note=devices_note)


def build_email(d: dict) -> tuple[str, str, str]:
    """d: {iface, now(date), created(date), yesterday(dict|None),
    month(dict|None), rows(list[dict]), ntopng(dict|None, optional, default
    None via .get()), top_n(int, optional, default 5 via .get())}
    -> (subject, plain_body, html_body)."""
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
    day_count = len(d["rows"])
    if month:
        total_style = "padding:6px 12px;border-top:2px solid #3c3f45;font-weight:600"
        row_html.append(
            f'<tr><td style="{total_style};text-align:left;color:#e8eaed">Total</td>'
            f'<td style="{total_style};text-align:right;color:#e8eaed">{human(month["rx"])}</td>'
            f'<td style="{total_style};text-align:right;color:#e8eaed">{human(month["tx"])}</td>'
            f'<td style="{total_style};text-align:right;color:#f5b942">{human(month["rx"] + month["tx"])}</td></tr>'
        )
    days_table = _table(
        f'Days this month ({day_count})' if day_count else 'This month',
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

    return subject, plain, html


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
    by traffic. Returns None (never raises) if the journal is unreadable or
    has no flows for yesterday — the core vnstat digest doesn't depend on
    this."""
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

    return {"talkers": top_talkers(flows)}


def gather(iface: str, top_n: int) -> dict:
    raw = fetch_raw(iface)
    traffic = extract_traffic(raw, iface)
    now = datetime.now(IST).date()
    derived = derive(traffic, now)
    created = next(e for e in raw["interfaces"] if e["name"] == iface)["created"]["date"]
    return {
        "iface": iface,
        "now": now,
        "created": _to_date(created),
        "ntopng": gather_ntopng(now),
        "top_n": top_n,
        **derived,
    }


def main() -> int:
    try:
        d = gather(VNSTAT_IFACE, TOP_N)
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
