#!/home/madhur/.virtualenvs/python-rsha/bin/python
"""Firefly III financial digest -> Mailpit (daily / weekly / monthly).

Emails a summary of money movement from Firefly III over a period: spent / earned /
net headline, spend broken down by category, the period's individual transactions,
an uncategorized-transaction callout, and a transfers note.

Pick the window with a positional argument (default ``daily``):
  daily    -> yesterday (runs from ~/scripts/every_24_hours.sh)
  weekly   -> trailing 7 days ending yesterday (runs from ~/scripts/every_week.sh)
  monthly  -> the previous calendar month (runs from ~/scripts/every_month.sh)

For weekly/monthly the per-transaction table is capped to the largest TXN_LIMIT
rows (a month can have hundreds); the category/income breakdowns stay complete.

Sibling of the AWS-cost and Claude-Code (ccusage) digests — together they cover
cloud spend, LLM spend, and personal finance. Uses the shared instrumented
homelab Firefly client (every call surfaces in Prometheus as service=firefly,
source=firefly_digest) and the Mailpit client (service=mailpit). Invoked daily
from ~/scripts/every_24_hours.sh.

Notes baked in from how this Firefly instance is modelled:
  - Credit cards are asset accounts (account_role=ccAsset), NOT liabilities, so
    CC spend shows up as ordinary withdrawals in the expense insights.
  - Transfers between own accounts (incl. CC paydowns) are NOT spend; Firefly's
    expense insight already excludes them. We surface them separately as a note.
  - Every imported row should carry a category (see firefly_category_required);
    the "uncategorized" section flags any that slipped through (usually manual).

Config (override via firefly-digest.env):
  MAIL_FROM         (default firefly-digest@madhur.co.in)
  MAIL_TO           (default ahuja.madhur@gmail.com)
  FIREFLY_ENV_FILE  (default /home/madhur/Desktop/python/.env — holds FIREFLY_*)
  CURRENCY          (default INR)
"""

from __future__ import annotations

import argparse
import html as _html
import os
import sys
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from pathlib import Path

from dotenv import load_dotenv

from homelab import metrics, set_source
from homelab.clients import mailpit
from homelab.clients.firefly import FireflyClient
from homelab.errors import FireflyError

set_source("firefly_digest")

SCRIPT_DIR = Path(__file__).resolve().parent
load_dotenv(SCRIPT_DIR / "firefly-digest.env")

MAIL_FROM = os.environ.get("MAIL_FROM", "firefly-digest@madhur.co.in")
MAIL_TO = os.environ.get("MAIL_TO", "ahuja.madhur@gmail.com")
FIREFLY_ENV_FILE = os.environ.get("FIREFLY_ENV_FILE", "/home/madhur/Desktop/python/.env")
CURRENCY = os.environ.get("CURRENCY", "INR")

# Pull FIREFLY_BASE_URL / FIREFLY_PAT into the environment for FireflyClient.
load_dotenv(FIREFLY_ENV_FILE)

IST = timezone(timedelta(hours=5, minutes=30))
_SYM = {"INR": "₹", "USD": "$", "EUR": "€", "GBP": "£"}

# Cap the per-transaction table for multi-day periods (a month can run to
# hundreds of rows). ``None`` -> show every transaction (the daily digest).
TXN_LIMIT = {"daily": None, "weekly": 20, "monthly": 20}


def resolve_period(period: str, today: date) -> dict:
    """Map a period name to its date window and human labels."""
    if period == "daily":
        start = end = today - timedelta(days=1)
        return {
            "start": start,
            "end": end,
            "period_label": start.strftime("%A, %d %b %Y"),
            "subject_tag": "",
            "subject_range": start.strftime("%d %b"),
        }
    if period == "weekly":
        end = today - timedelta(days=1)
        start = end - timedelta(days=6)
        return {
            "start": start,
            "end": end,
            "period_label": f"{start.strftime('%d %b')} – {end.strftime('%d %b %Y')} · last 7 days",
            "subject_tag": " · weekly",
            "subject_range": f"{start.strftime('%d')}–{end.strftime('%d %b')}",
        }
    if period == "monthly":
        end = today.replace(day=1) - timedelta(days=1)  # last day of previous month
        start = end.replace(day=1)
        return {
            "start": start,
            "end": end,
            "period_label": start.strftime("%B %Y"),
            "subject_tag": " · monthly",
            "subject_range": start.strftime("%b %Y"),
        }
    raise ValueError(f"unknown period: {period!r}")

# --------------------------------------------------------------------------- #
# Formatting
# --------------------------------------------------------------------------- #
def money(amount, code: str = CURRENCY) -> str:
    sym = _SYM.get(code, f"{code} ")
    a = float(amount)
    s = f"{sym}{abs(a):,.2f}"
    return f"-{s}" if a < 0 else s


def _esc(s) -> str:
    return _html.escape(str(s))

# --------------------------------------------------------------------------- #
# Data
# --------------------------------------------------------------------------- #
def gather(ff: FireflyClient, start: str, end: str) -> dict:
    """Collect everything the digest needs for the date range `start`..`end` (YYYY-MM-DD, inclusive)."""
    expense_cats = [
        {"name": r.get("name") or "(uncategorized)", "amount": abs(float(r.get("difference_float") or 0))}
        for r in ff.insight_expense_by_category(start, end)
    ]
    expense_cats.sort(key=lambda x: x["amount"], reverse=True)
    income_cats = [
        {"name": r.get("name") or "(uncategorized)", "amount": abs(float(r.get("difference_float") or 0))}
        for r in ff.insight_income_by_category(start, end)
    ]
    income_cats.sort(key=lambda x: x["amount"], reverse=True)

    spent = sum(c["amount"] for c in expense_cats)
    earned = sum(c["amount"] for c in income_cats)

    txns = ff.list_transactions(start, end, types=["withdrawal", "deposit"])
    txns.sort(key=lambda t: float(t["amount"]), reverse=True)
    uncategorized = [t for t in txns if not (t.get("category_name") or "").strip()]

    transfers = ff.list_transactions(start, end, types=["transfer"])
    transfer_total = sum(float(t["amount"]) for t in transfers)

    return {
        "spent": spent,
        "earned": earned,
        "net": earned - spent,
        "expense_cats": expense_cats,
        "income_cats": income_cats,
        "txns": txns,
        "uncategorized": uncategorized,
        "transfers": transfers,
        "transfer_total": transfer_total,
    }

# --------------------------------------------------------------------------- #
# HTML
# --------------------------------------------------------------------------- #
def _stat(label: str, value: str, accent: str = "#e8eaed") -> str:
    return (
        '<td style="padding:10px 16px;background:#232427;border-radius:8px;text-align:center">'
        f'<div style="color:#9aa0a6;font-size:11px;text-transform:uppercase;letter-spacing:.5px">{label}</div>'
        f'<div style="color:{accent};font-size:22px;font-weight:600;margin-top:4px">{value}</div></td>'
    )


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


def _cell(text: str, align: str = "left", color: str = "") -> str:
    style = f"padding:6px 12px;border-bottom:1px solid #2c2e33;text-align:{align}"
    if color:
        style += f";color:{color}"
    return f'<td style="{style}">{text}</td>'


def build_html(ctx: dict, d: dict) -> str:
    net = d["net"]
    headline = (
        '<table style="border-spacing:10px 0;width:100%"><tr>'
        + _stat("Spent", money(d["spent"]), "#f28b82")
        + _stat("Earned", money(d["earned"]), "#81c995")
        + _stat("Net", money(net), "#81c995" if net >= 0 else "#f28b82")
        + "</tr></table>"
    )

    # Spend by category.
    cat_rows = [
        f'<tr>{_cell(_esc(c["name"]))}{_cell(money(c["amount"]), "right")}</tr>'
        for c in d["expense_cats"]
    ]
    cat_table = _table(
        "💸 Spend by category",
        [("Category", "left"), ("Amount", "right")],
        cat_rows,
    )

    # Income by category (only if any).
    inc_rows = [
        f'<tr>{_cell(_esc(c["name"]))}{_cell(money(c["amount"]), "right", "#81c995")}</tr>'
        for c in d["income_cats"]
    ]
    inc_table = _table(
        "💰 Income by category",
        [("Category", "left"), ("Amount", "right")],
        inc_rows,
    )

    # Transactions (capped to the largest `txn_limit` rows for multi-day periods).
    limit = ctx.get("txn_limit")
    shown = d["txns"][:limit] if limit else d["txns"]
    txn_rows = []
    for t in shown:
        is_out = t["type"] == "withdrawal"
        counterparty = t["destination"] if is_out else t["source"]
        account = t["source"] if is_out else t["destination"]
        amt = money(t["amount"], t.get("currency_code") or CURRENCY)
        amt = f"-{amt}" if is_out else f"+{amt}"
        color = "#f28b82" if is_out else "#81c995"
        cat = t.get("category_name") or '<span style="color:#f5b942">— none —</span>'
        txn_rows.append(
            "<tr>"
            + _cell(_esc(t["description"]))
            + _cell(_esc(counterparty), "left", "#9aa0a6")
            + _cell(cat, "left", "#9aa0a6")
            + _cell(_esc(account), "left", "#5f6571")
            + _cell(amt, "right", color)
            + "</tr>"
        )
    txn_note = (
        f"Showing the {len(shown)} largest of {len(d['txns'])} transactions."
        if limit and len(d["txns"]) > len(shown)
        else ""
    )
    title = "🧾 Transactions" if not limit else "🧾 Top transactions"
    txn_table = _table(
        title,
        [("Description", "left"), ("Counterparty", "left"), ("Category", "left"),
         ("Account", "left"), ("Amount", "right")],
        txn_rows,
        txn_note,
    )

    # Uncategorized callout.
    if d["uncategorized"]:
        u_rows = [
            f'<tr>{_cell(_esc(t["description"]))}'
            f'{_cell(_esc(t["destination"] if t["type"] == "withdrawal" else t["source"]), "left", "#9aa0a6")}'
            f'{_cell(money(t["amount"], t.get("currency_code") or CURRENCY), "right", "#f5b942")}</tr>'
            for t in d["uncategorized"]
        ]
        uncategorized = (
            '<h3 style="margin:24px 0 6px;color:#f5b942;font-size:15px">⚠️ Uncategorized transactions</h3>'
            '<table style="width:100%;border-collapse:collapse;font-size:13px">'
            '<tr><th style="text-align:left;padding:6px 12px;color:#9aa0a6;font-weight:500">Description</th>'
            '<th style="text-align:left;padding:6px 12px;color:#9aa0a6;font-weight:500">Counterparty</th>'
            '<th style="text-align:right;padding:6px 12px;color:#9aa0a6;font-weight:500">Amount</th></tr>'
            + "".join(u_rows) + "</table>"
            '<p style="color:#5f6571;font-size:11px;margin:4px 12px">These have no category — '
            "every row should carry one. Likely manual entries.</p>"
        )
    else:
        uncategorized = (
            '<p style="color:#81c995;margin:18px 0 0;font-size:13px">✓ All transactions categorized.</p>'
        )

    # Transfers note.
    if d["transfers"]:
        transfers_note = (
            f'<p style="color:#9aa0a6;margin:14px 0 0;font-size:13px">🔁 {len(d["transfers"])} '
            f'own-account transfer(s) totalling {money(d["transfer_total"])} '
            "(not counted as spend — e.g. CC paydowns / moves).</p>"
        )
    else:
        transfers_note = ""

    return f"""<html><head><meta name="color-scheme" content="dark"><style>html,body{{margin:0;background:#1b1b1d}}</style></head>
<body style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;font-size:14px;color:#d7dade;background:#1b1b1d;padding:18px">
<p style="color:#9aa0a6;margin-top:0">Firefly III · {ctx["period_label"]} · generated {ctx["generated"]}</p>
{headline}
{transfers_note}
{cat_table}
{inc_table}
{txn_table}
{uncategorized}
<hr style="border:none;border-top:1px solid #33353a;margin:22px 0">
<p style="font-size:11px;color:#5f6571">Spend excludes own-account transfers (Firefly insight). Credit cards are modelled as asset accounts, so CC purchases appear as ordinary withdrawals.</p>
</body></html>"""

# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #
def main() -> int:
    parser = argparse.ArgumentParser(description="Firefly III financial digest -> Mailpit.")
    parser.add_argument(
        "period",
        nargs="?",
        default="daily",
        choices=["daily", "weekly", "monthly"],
        help="reporting window (default: daily)",
    )
    args = parser.parse_args()
    period = args.period

    today = datetime.now(IST).date()
    p = resolve_period(period, today)
    start, end = p["start"].isoformat(), p["end"].isoformat()

    try:
        with FireflyClient(dict(os.environ)) as ff:
            d = gather(ff, start, end)
    except FireflyError as e:
        print(f"ERROR: Firefly query failed: {e}", file=sys.stderr)
        return 1

    ctx = {
        "period_label": p["period_label"],
        "generated": datetime.now(IST).strftime("%d %b %H:%M IST"),
        "txn_limit": TXN_LIMIT[period],
    }

    net = d["net"]
    subject = (
        f"Firefly{p['subject_tag']} — {money(d['spent'])} spent · {money(d['earned'])} earned · "
        f"net {money(net)} ({p['subject_range']})"
    )
    if d["uncategorized"]:
        subject += f" · ⚠️{len(d['uncategorized'])} uncategorized"

    ok = mailpit.push(
        subject,
        sender=f"Firefly Digest <{MAIL_FROM}>",
        body=(
            f"{p['period_label']}: spent {money(d['spent'])}, earned {money(d['earned'])}, "
            f"net {money(net)} across {len(d['txns'])} transaction(s). "
            "View HTML in Mailpit for the category, transaction and balance tables."
        ),
        html=build_html(ctx, d),
        recipient=MAIL_TO,
    )
    if not ok:
        print("ERROR: Mailpit send failed", file=sys.stderr)
        return 1

    print(
        f"Sent Firefly {period} digest -> {MAIL_TO} ({start}..{end}: spent {money(d['spent'])}, "
        f"earned {money(d['earned'])}, net {money(net)}, {len(d['txns'])} txns, "
        f"{len(d['uncategorized'])} uncategorized)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
