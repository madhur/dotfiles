#!/home/madhur/.virtualenvs/python-rsha/bin/python
"""Firefly III daily financial digest -> Mailpit.

Emails a summary of YESTERDAY's money movement from Firefly III: spent / earned /
net headline, spend broken down by category, the day's individual transactions,
an uncategorized-transaction callout, and a transfers note.

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

import html as _html
import os
import sys
from datetime import datetime, timedelta, timezone
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
def gather(ff: FireflyClient, day: str) -> dict:
    """Collect everything the digest needs for the single date `day` (YYYY-MM-DD)."""
    expense_cats = [
        {"name": r.get("name") or "(uncategorized)", "amount": abs(float(r.get("difference_float") or 0))}
        for r in ff.insight_expense_by_category(day, day)
    ]
    expense_cats.sort(key=lambda x: x["amount"], reverse=True)
    income_cats = [
        {"name": r.get("name") or "(uncategorized)", "amount": abs(float(r.get("difference_float") or 0))}
        for r in ff.insight_income_by_category(day, day)
    ]
    income_cats.sort(key=lambda x: x["amount"], reverse=True)

    spent = sum(c["amount"] for c in expense_cats)
    earned = sum(c["amount"] for c in income_cats)

    txns = ff.list_transactions(day, day, types=["withdrawal", "deposit"])
    txns.sort(key=lambda t: float(t["amount"]), reverse=True)
    uncategorized = [t for t in txns if not (t.get("category_name") or "").strip()]

    transfers = ff.list_transactions(day, day, types=["transfer"])
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

    # Transactions.
    txn_rows = []
    for t in d["txns"]:
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
    txn_table = _table(
        "🧾 Transactions",
        [("Description", "left"), ("Counterparty", "left"), ("Category", "left"),
         ("Account", "left"), ("Amount", "right")],
        txn_rows,
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
<p style="color:#9aa0a6;margin-top:0">Firefly III · {ctx["day_label"]} · generated {ctx["generated"]}</p>
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
    today = datetime.now(IST).date()
    yesterday = today - timedelta(days=1)
    day = yesterday.isoformat()

    try:
        with FireflyClient(dict(os.environ)) as ff:
            d = gather(ff, day)
    except FireflyError as e:
        print(f"ERROR: Firefly query failed: {e}", file=sys.stderr)
        return 1

    ctx = {
        "day_label": yesterday.strftime("%A, %d %b %Y"),
        "generated": datetime.now(IST).strftime("%d %b %H:%M IST"),
    }

    net = d["net"]
    subject = (
        f"Firefly — {money(d['spent'])} spent · {money(d['earned'])} earned · "
        f"net {money(net)} ({yesterday.strftime('%d %b')})"
    )
    if d["uncategorized"]:
        subject += f" · ⚠️{len(d['uncategorized'])} uncategorized"

    ok = mailpit.push(
        subject,
        sender=f"Firefly Digest <{MAIL_FROM}>",
        body=(
            f"{ctx['day_label']}: spent {money(d['spent'])}, earned {money(d['earned'])}, "
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
        f"Sent Firefly digest -> {MAIL_TO} ({day}: spent {money(d['spent'])}, "
        f"earned {money(d['earned'])}, net {money(net)}, {len(d['txns'])} txns, "
        f"{len(d['uncategorized'])} uncategorized)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
