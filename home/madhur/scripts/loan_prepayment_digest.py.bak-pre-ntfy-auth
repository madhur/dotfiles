#!/home/madhur/.virtualenvs/python-rsha/bin/python
"""SBI home loan prepayment digest -> Mailpit + ntfy (weekly).

Fetches the current outstanding balance from Firefly III, infers this week's
prepayment pace (current balance vs. what it would be with zero prepayment,
per prepayment_simulator.py), and projects payoff two ways: continuing that
pace, and stopping prepayment today. Emails the full comparison to Mailpit
and pushes a headline to ntfy.

Sibling of the other ~/scripts/*_digest.py scripts — same shape: a
*-digest.env sidecar, the shared homelab Mailpit/Firefly clients. Invoked
weekly from ~/scripts/every_week.sh.

Config (override via loan-prepayment-digest.env):
  MAIL_FROM, MAIL_TO, FIREFLY_ENV_FILE, LOAN_ACCOUNT_MATCH,
  CURRENT_RATE, EMI, ORIGINAL_PRINCIPAL, ORIGINAL_RATE, ORIGINAL_MONTHS,
  ORIGINAL_START, LOAN_NTFY_TOPIC, NTFY_SERVER
"""
from __future__ import annotations

import argparse
import os
import sys
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

from dotenv import load_dotenv

SCRIPT_DIR = Path(__file__).resolve().parent
load_dotenv(SCRIPT_DIR / "loan-prepayment-digest.env")

LOAN_DOCS_DIR = "/home/madhur/Desktop/home_documents/loan_documents"
sys.path.insert(0, LOAN_DOCS_DIR)
from amortization import add_month, amortize, compute_tenure, inr, parse_date  # noqa: E402
from prepayment_simulator import infer_monthly_prepay, months_between, project_with_monthly_prepay  # noqa: E402

from homelab import set_source  # noqa: E402
from homelab.clients import mailpit  # noqa: E402
from homelab.clients.firefly import FireflyClient  # noqa: E402
from homelab.clients.ntfy import NtfyNotifier  # noqa: E402
from homelab.errors import FireflyError  # noqa: E402

set_source("loan_prepayment_digest")

MAIL_FROM = os.environ.get("MAIL_FROM", "loan-digest@madhur.co.in")
MAIL_TO = os.environ.get("MAIL_TO", "ahuja.madhur@gmail.com")
FIREFLY_ENV_FILE = os.environ.get("FIREFLY_ENV_FILE", "/home/madhur/Desktop/python/.env")
LOAN_ACCOUNT_MATCH = os.environ.get("LOAN_ACCOUNT_MATCH", "SBI Loan")
NTFY_SERVER = os.environ.get("NTFY_SERVER", "https://ntfy.madhur.co.in")
LOAN_NTFY_TOPIC = os.environ.get("LOAN_NTFY_TOPIC", "transactions")

load_dotenv(FIREFLY_ENV_FILE)

IST = timezone(timedelta(hours=5, minutes=30))


def find_loan_account(accounts: list[dict], match: str) -> dict:
    """Pick the one asset account whose name contains `match` (case-insensitive).
    Raises ValueError if zero or more than one account matches."""
    hits = [a for a in accounts if match.lower() in a["attributes"]["name"].lower()]
    if not hits:
        raise ValueError(f"no asset account name contains {match!r}")
    if len(hits) > 1:
        names = [a["attributes"]["name"] for a in hits]
        raise ValueError(f"{len(hits)} asset accounts match {match!r}: {names}")
    return hits[0]


# --------------------------------------------------------------------------- #
# Core loan math
# --------------------------------------------------------------------------- #
def compute_scenarios(outstanding: int, today: date, cfg: dict) -> dict:
    """Pure function: given the current outstanding balance and today's date,
    compute both payoff scenarios (no further prepayment vs. continuing the
    inferred current pace). `cfg` holds rate/emi/original-loan constants —
    see build_cfg_from_env(). Raises ValueError if the EMI can't cover
    interest on `outstanding` at `cfg['rate']` (loan would never amortize)."""
    rate = cfg["rate"]
    emi = cfg["emi"]
    original_start = cfg["original_start"]
    monthly_r = rate / 12 / 100

    elapsed = months_between(original_start, today)
    next_date = original_start
    for _ in range(elapsed):
        next_date = add_month(next_date)

    baseline_months = compute_tenure(outstanding, monthly_r, emi)
    baseline_rows = list(amortize(outstanding, rate, baseline_months, next_date,
                                   exact_payoff=True, emi_override=emi))
    baseline_interest = sum(row[3] for row in baseline_rows)
    baseline_close_date = baseline_rows[-1][1]

    result = {
        "outstanding": outstanding,
        "today": today,
        "rate": rate,
        "emi": emi,
        "elapsed_months": elapsed,
        "next_date": next_date,
        "pace_known": False,
        "monthly_prepay": 0,
        "baseline_months": baseline_months,
        "baseline_close_date": baseline_close_date,
        "baseline_interest": baseline_interest,
        "projected_months": baseline_months,
        "projected_close_date": baseline_close_date,
        "projected_interest": baseline_interest,
        "extra_prepaid": 0,
        "interest_saved": 0,
    }

    try:
        _, monthly_prepay = infer_monthly_prepay(
            cfg["original_principal"], cfg["original_rate"], cfg["original_months"],
            original_start, emi, today, outstanding)
    except ValueError:
        return result

    rows = list(project_with_monthly_prepay(outstanding, rate, emi, monthly_prepay, next_date))
    total_interest = sum(row[2] for row in rows)
    total_extra = sum(row[4] for row in rows)

    result.update({
        "pace_known": True,
        "monthly_prepay": monthly_prepay,
        "projected_months": len(rows),
        "projected_close_date": rows[-1][1],
        "projected_interest": total_interest,
        "extra_prepaid": total_extra,
        "interest_saved": baseline_interest - total_interest,
    })
    return result


def build_cfg_from_env() -> dict:
    """Read CURRENT_RATE/EMI/ORIGINAL_* env vars into compute_scenarios's cfg shape."""
    return {
        "rate": float(os.environ.get("CURRENT_RATE", 7.5)),
        "emi": round(float(os.environ.get("EMI", 136951))),
        "original_principal": round(float(os.environ.get("ORIGINAL_PRINCIPAL", 17000000))),
        "original_rate": float(os.environ.get("ORIGINAL_RATE", 7.5)),
        "original_months": int(os.environ.get("ORIGINAL_MONTHS", 240)),
        "original_start": parse_date(os.environ.get("ORIGINAL_START", "05/04/2026")),
    }


# --------------------------------------------------------------------------- #
# Rendering
# --------------------------------------------------------------------------- #
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
    head = "".join(
        f'<th style="text-align:{align};padding:6px 12px;color:#9aa0a6;font-weight:500">{label}</th>'
        for label, align in headers
    )
    note_html = f'<p style="color:#5f6571;font-size:11px;margin:4px 12px">{note}</p>' if note else ""
    return (
        f'<h3 style="margin:24px 0 6px;color:#e8eaed;font-size:15px">{title}</h3>'
        '<table style="width:100%;border-collapse:collapse;font-size:13px">'
        f"<tr>{head}</tr>" + "".join(rows) + "</table>" + note_html
    )


def build_email(r: dict, generated: str) -> tuple[str, str, str]:
    """Returns (subject, plaintext_body, html) for the Mailpit send."""
    close = r["projected_close_date"].strftime("%d %b %Y")
    subject = (
        f"Loan Prepayment Digest — Rs {inr(r['outstanding'])} outstanding "
        f"· closes ~{close}"
    )

    headline = (
        '<table style="border-spacing:10px 0;width:100%"><tr>'
        + _stat("Outstanding", f"Rs {inr(r['outstanding'])}")
        + _stat("Monthly pace", f"Rs {inr(r['monthly_prepay'])}" if r["pace_known"] else "—",
                "#81c995" if r["pace_known"] else "#9aa0a6")
        + _stat("Projected close", r["projected_close_date"].strftime("%b %Y"), "#81c995")
        + "</tr></table>"
    )

    rows = [
        "<tr>" + _cell("No further prepayment")
        + _cell(f"{r['baseline_months']} mo ({r['baseline_months']/12:.1f} yrs)")
        + _cell(r["baseline_close_date"].strftime("%d/%m/%Y"))
        + _cell(f"Rs {inr(r['baseline_interest'])}", "right") + "</tr>",
    ]
    if r["pace_known"]:
        rows.append(
            "<tr>" + _cell("Continuing current pace", color="#81c995")
            + _cell(f"{r['projected_months']} mo ({r['projected_months']/12:.1f} yrs)")
            + _cell(r["projected_close_date"].strftime("%d/%m/%Y"))
            + _cell(f"Rs {inr(r['projected_interest'])}", "right", "#81c995") + "</tr>"
        )
    scenario_table = _table(
        "\U0001F4CA Payoff scenarios",
        [("Scenario", "left"), ("Tenure", "left"), ("Closes", "left"), ("Interest remaining", "right")],
        rows,
    )

    if r["pace_known"]:
        pace_note = (
            '<p style="color:#9aa0a6;margin:14px 0 0;font-size:13px">'
            f"Inferred prepayment pace: Rs {inr(r['monthly_prepay'])}/month "
            f"(Rs {inr(r['monthly_prepay']*12)}/year) from {r['elapsed_months']} elapsed EMI(s). "
            f"Extra prepaid before close: Rs {inr(r['extra_prepaid'])}. "
            f"Interest saved vs. no further prepayment: Rs {inr(r['interest_saved'])}.</p>"
        )
    else:
        pace_note = (
            '<p style="color:#f5b942;margin:14px 0 0;font-size:13px">'
            "No prepayment pace detected this run (balance isn't below the "
            "no-prepayment baseline yet) — showing the no-further-prepayment "
            "scenario only.</p>"
        )

    html = f"""<html><head><meta name="color-scheme" content="dark"><style>html,body{{margin:0;background:#1b1b1d}}</style></head>
<body style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;font-size:14px;color:#d7dade;background:#1b1b1d;padding:18px">
<p style="color:#9aa0a6;margin-top:0">SBI Home Loan · as of {r['today']:%d %b %Y} · generated {generated}</p>
{headline}
{scenario_table}
{pace_note}
<hr style="border:none;border-top:1px solid #33353a;margin:22px 0">
<p style="font-size:11px;color:#5f6571">Assumes {r['rate']:.2f}% p.a. holds constant (floating/EBLR-linked in reality) and EMI Rs {inr(r['emi'])} stays fixed. Update CURRENT_RATE in loan-prepayment-digest.env on a rate reset.</p>
</body></html>"""

    if r["pace_known"]:
        plain = (
            f"Outstanding Rs {inr(r['outstanding'])} as of {r['today']:%d/%m/%Y}. "
            f"Continuing pace (~Rs {inr(r['monthly_prepay'])}/mo) -> closes {close}, "
            f"interest left Rs {inr(r['projected_interest'])}. "
            "View HTML in Mailpit for the full comparison table."
        )
    else:
        plain = (
            f"Outstanding Rs {inr(r['outstanding'])} as of {r['today']:%d/%m/%Y}. "
            f"No further prepayment -> closes {close}, "
            f"interest left Rs {inr(r['baseline_interest'])}. "
            "View HTML in Mailpit for details."
        )
    return subject, plain, html


def build_ntfy_message(r: dict) -> tuple[str, str]:
    """Returns (title, body) for the ntfy headline push."""
    close = r["projected_close_date"].strftime("%b %Y")
    title = f"\U0001F3E0 SBI Loan: closes ~{close}"
    if r["pace_known"]:
        body = (
            f"Outstanding: Rs {inr(r['outstanding'])} (as of {r['today']:%d/%m/%Y})\n"
            f"Pace: Rs {inr(r['monthly_prepay'])}/month (Rs {inr(r['monthly_prepay']*12)}/year)\n"
            f"Continuing pace -> closes {r['projected_close_date']:%b %Y}, "
            f"interest left Rs {inr(r['projected_interest'])}\n"
            f"No further prepay -> closes {r['baseline_close_date']:%b %Y}, "
            f"interest left Rs {inr(r['baseline_interest'])}"
        )
    else:
        body = (
            f"Outstanding: Rs {inr(r['outstanding'])} (as of {r['today']:%d/%m/%Y})\n"
            "No prepayment pace detected yet (balance not below the no-prepayment baseline).\n"
            f"At the current EMI alone -> closes {r['baseline_close_date']:%b %Y}, "
            f"interest left Rs {inr(r['baseline_interest'])}"
        )
    return title, body


# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #
def main() -> int:
    parser = argparse.ArgumentParser(
        description="Weekly SBI loan prepayment digest -> Mailpit + ntfy.")
    parser.add_argument("--dry-run", action="store_true",
                        help="print the computed digest instead of sending it")
    args = parser.parse_args()

    cfg = build_cfg_from_env()

    try:
        with FireflyClient(dict(os.environ)) as ff:
            accounts = ff.list_accounts("asset")
    except FireflyError as e:
        print(f"ERROR: Firefly query failed: {e}", file=sys.stderr)
        return 1

    try:
        account = find_loan_account(accounts, LOAN_ACCOUNT_MATCH)
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

    outstanding = abs(round(float(account["attributes"]["current_balance"])))
    today = datetime.now(IST).date()

    try:
        r = compute_scenarios(outstanding, today, cfg)
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

    generated = datetime.now(IST).strftime("%d %b %H:%M IST")
    subject, plain, html = build_email(r, generated)
    ntfy_title, ntfy_body = build_ntfy_message(r)

    if args.dry_run:
        print(f"Subject: {subject}")
        print(plain)
        print()
        print(f"[ntfy -> {LOAN_NTFY_TOPIC}] {ntfy_title}")
        print(ntfy_body)
        return 0

    mail_ok = mailpit.push(
        subject, sender=f"Loan Digest <{MAIL_FROM}>", body=plain, html=html, recipient=MAIL_TO)
    if not mail_ok:
        print("ERROR: Mailpit send failed", file=sys.stderr)

    notifier = NtfyNotifier({
        "enabled": True,
        "server_url": NTFY_SERVER,
        "topic": LOAN_NTFY_TOPIC,
    })
    ntfy_ok = notifier.send_notification(message=ntfy_body, title=ntfy_title, tags="house")
    if not ntfy_ok:
        print("ERROR: ntfy send failed", file=sys.stderr)

    return 0 if (mail_ok and ntfy_ok) else 1


if __name__ == "__main__":
    sys.exit(main())
