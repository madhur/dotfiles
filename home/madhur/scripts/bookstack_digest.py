#!/home/madhur/.virtualenvs/python-rsha/bin/python
"""BookStack daily digest -> Mailpit (Python port of bookstack-digest.sh).

Lists pages created/modified in the last WINDOW_HOURS and emails a grouped HTML
summary to Mailpit. Uses the instrumented homelab clients, so BookStack API calls
and the Mailpit send show up in Prometheus (service=bookstack / mailpit,
source=bookstack_digest). Invoked daily from ~/scripts/every_24_hours.sh.

Config (override via bookstack-digest.env, same keys as the old shell script):
  BS_TOKEN_ID / BS_TOKEN_SECRET   (required)
  API_URL        (default http://localhost:6875)
  PUBLIC_URL     (default https://bookstack.desktop.madhur.co.in)
  WINDOW_HOURS   (default 24)
  MAIL_FROM / MAIL_TO
  SEND_WHEN_EMPTY (default false)
"""

from __future__ import annotations

import html as _html
import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

from dotenv import load_dotenv

from homelab import set_source
from homelab.clients.bookstack import BookStackClient
from homelab.clients import mailpit
from homelab.errors import BookStackError

set_source("bookstack_digest")

SCRIPT_DIR = Path(__file__).resolve().parent
load_dotenv(SCRIPT_DIR / "bookstack-digest.env")

API_URL = os.environ.get("API_URL", "http://localhost:6875")
PUBLIC_URL = os.environ.get("PUBLIC_URL", "https://bookstack.desktop.madhur.co.in")
WINDOW_HOURS = int(os.environ.get("WINDOW_HOURS", "24"))
MAIL_FROM = os.environ.get("MAIL_FROM", "bookstack-digest@madhur.co.in")
MAIL_TO = os.environ.get("MAIL_TO", "ahuja.madhur@gmail.com")
SEND_WHEN_EMPTY = os.environ.get("SEND_WHEN_EMPTY", "false").lower() == "true"

IST = timezone(timedelta(hours=5, minutes=30))


def _iso_z(dt: datetime) -> str:
    # Match BookStack's "2025-12-28T10:21:50.000000Z" so string comparisons line up.
    return dt.strftime("%Y-%m-%dT%H:%M:%S.000000Z")


def _ist(ts: str) -> str:
    # "2025-12-28T10:21:50.000000Z" -> "28 Dec 15:51 IST"
    clean = ts.replace("Z", "+00:00")
    dt = datetime.fromisoformat(clean).astimezone(IST)
    return dt.strftime("%d %b %H:%M") + " IST"


def _author(updated_by, users_map: dict) -> str:
    if isinstance(updated_by, dict):
        return updated_by.get("name") or "unknown"
    if isinstance(updated_by, (int, str)) and str(updated_by).isdigit():
        return users_map.get(str(updated_by), f"user#{updated_by}")
    return "unknown"


def _li(p: dict, books_map: dict, users_map: dict) -> str:
    binfo = books_map.get(str(p.get("book_id")), {"slug": "", "name": "?"})
    slug = binfo.get("slug") or ""
    url = "#" if not slug else f"{PUBLIC_URL}/books/{slug}/page/{p.get('slug', '')}"
    return (
        f'<li style="margin:8px 0"><a href="{url}" '
        f'style="color:#6cb6ff;text-decoration:none">{_html.escape(p.get("name", ""))}</a>'
        f'<br><span style="color:#9aa0a6;font-size:12px">'
        f'{_html.escape(binfo.get("name", "?"))} · by '
        f'{_html.escape(_author(p.get("updated_by"), users_map))} · '
        f'{_ist(p.get("updated_at", ""))}</span></li>'
    )


def _section(title: str, count: int, items_html: str) -> str:
    if count == 0:
        return ""
    return (
        f'<h3 style="margin:20px 0 4px;color:#e8eaed;font-size:15px">{title} ({count})</h3>\n'
        f'<ul style="margin:0;padding-left:20px">\n{items_html}\n</ul>\n'
    )


def main() -> int:
    token_id = os.environ.get("BS_TOKEN_ID")
    token_secret = os.environ.get("BS_TOKEN_SECRET")
    if not token_id or not token_secret:
        print("ERROR: BS_TOKEN_ID / BS_TOKEN_SECRET not set (see bookstack-digest.env)",
              file=sys.stderr)
        return 1

    now = datetime.now(timezone.utc)
    cutoff = _iso_z(now - timedelta(hours=WINDOW_HOURS))
    # Generous server-side filter (extra 12h buffer); precise window enforced below.
    filter_cutoff = (now - timedelta(hours=WINDOW_HOURS + 12)).strftime("%Y-%m-%d %H:%M:%S")

    bs = BookStackClient(base_url=API_URL, token_id=token_id, token_secret=token_secret)

    try:
        pages = bs.list_pages(params={
            "filter[updated_at:gte]": filter_cutoff,
            "sort": "-updated_at",
            "count": 500,
        })
    except BookStackError as e:
        print(f"ERROR: /api/pages fetch failed: {e}", file=sys.stderr)
        return 1

    # Best-effort lookups (need extra token perms); fall back to empty maps.
    try:
        books_map = {str(b["id"]): {"slug": b.get("slug"), "name": b.get("name")}
                     for b in bs.list_books(params={"count": 500})}
    except BookStackError:
        books_map = {}
    try:
        users_map = {str(u["id"]): u.get("name") for u in bs.list_users(params={"count": 500})}
    except BookStackError:
        users_map = {}

    recent = [p for p in pages if p.get("updated_at", "") >= cutoff]
    added = [p for p in recent if p.get("created_at", "") >= cutoff]
    modified = [p for p in recent if p.get("created_at", "") < cutoff]
    total = len(added) + len(modified)

    if total == 0 and not SEND_WHEN_EMPTY:
        print(f"No BookStack changes in last {WINDOW_HOURS}h; SEND_WHEN_EMPTY=false, skipping mail.")
        return 0

    subject = (f"BookStack digest — {len(added)} added, {len(modified)} modified "
               f"({now.astimezone(IST).strftime('%d %b')})")

    if total == 0:
        body_inner = (f'<p style="color:#9aa0a6">No pages were added or modified in the last '
                      f'{WINDOW_HOURS} hours.</p>')
    else:
        added_html = "\n".join(_li(p, books_map, users_map) for p in added)
        modified_html = "\n".join(_li(p, books_map, users_map) for p in modified)
        body_inner = (_section("➕ Added", len(added), added_html)
                      + _section("✏️ Modified", len(modified), modified_html))

    html_doc = f"""<html><head><meta name="color-scheme" content="dark"><style>html,body{{margin:0;background:#1b1b1d}}</style></head>
<body style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;font-size:14px;color:#d7dade;background:#1b1b1d;padding:18px">
<p style="color:#9aa0a6;margin-top:0">Activity in the last <b style="color:#d7dade">{WINDOW_HOURS}h</b> (since {cutoff}).</p>
{body_inner}
<hr style="border:none;border-top:1px solid #33353a;margin:22px 0">
<p style="font-size:11px"><a href="{PUBLIC_URL}" style="color:#5f6571;text-decoration:none">{PUBLIC_URL}</a></p>
</body></html>"""

    ok = mailpit.push(
        subject,
        sender=f"BookStack Digest <{MAIL_FROM}>",
        body=f"{len(added)} added, {len(modified)} modified — view in Mailpit (HTML).",
        html=html_doc,
        recipient=MAIL_TO,
    )
    if not ok:
        print("ERROR: Mailpit send failed", file=sys.stderr)
        return 1

    print(f"Sent digest: {len(added)} added, {len(modified)} modified -> {MAIL_TO}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
