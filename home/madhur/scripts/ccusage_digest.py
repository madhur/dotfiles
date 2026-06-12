#!/home/madhur/.virtualenvs/python-rsha/bin/python
"""Claude Code usage digest -> Mailpit.

Emails a daily summary of local Claude Code token usage, parsed from
`ccusage daily --json` (which reads the JSONL logs under ~/.claude/projects;
no API calls). Covers a rolling WINDOW_DAYS window: headline totals, a per-day
table, and a per-model breakdown across the window.

ccusage is the de-facto standard usage analyzer for Claude Code. Cost figures
are ESTIMATES at public API rates — on a Max/Pro subscription they are not the
actual bill, just what the equivalent API usage would cost.

Uses the shared instrumented homelab Mailpit client, so the send shows up in
Prometheus (service=mailpit, source=ccusage_digest). Invoked daily from
~/scripts/every_24_hours.sh.

Config (override via ccusage-digest.env):
  MAIL_FROM     (default ccusage-digest@madhur.co.in)
  MAIL_TO       (default ahuja.madhur@gmail.com)
  WINDOW_DAYS   (default 7)
  CCUSAGE_CMD   (default "npx ccusage@latest")
"""

from __future__ import annotations

import html as _html
import json
import os
import shlex
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

from dotenv import load_dotenv

from homelab import metrics, set_source
from homelab.clients import mailpit

set_source("ccusage_digest")

SCRIPT_DIR = Path(__file__).resolve().parent
load_dotenv(SCRIPT_DIR / "ccusage-digest.env")

MAIL_FROM = os.environ.get("MAIL_FROM", "ccusage-digest@madhur.co.in")
MAIL_TO = os.environ.get("MAIL_TO", "ahuja.madhur@gmail.com")
WINDOW_DAYS = int(os.environ.get("WINDOW_DAYS", "7"))
CCUSAGE_CMD = os.environ.get("CCUSAGE_CMD", "npx ccusage@latest")

IST = timezone(timedelta(hours=5, minutes=30))

# --------------------------------------------------------------------------- #
# ccusage
# --------------------------------------------------------------------------- #
def fetch_usage(since: str) -> dict:
    """Run ccusage and return its parsed `daily --json` payload."""
    cmd = shlex.split(CCUSAGE_CMD) + ["daily", "--json", "--since", since]
    with metrics.track("ccusage", "daily"):
        proc = subprocess.run(
            cmd, capture_output=True, text=True, timeout=180, check=False
        )
    if proc.returncode != 0:
        raise RuntimeError(f"ccusage exited {proc.returncode}: {proc.stderr.strip()[:500]}")
    # ccusage may emit npm/install chatter on stderr; the JSON is on stdout.
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError as e:
        raise RuntimeError(f"could not parse ccusage JSON: {e}; stdout={proc.stdout[:300]!r}")


def aggregate_models(days: list[dict]) -> list[dict]:
    """Sum each model's tokens + cost across the whole window."""
    models: dict[str, dict] = {}
    for day in days:
        for mb in day.get("modelBreakdowns", []):
            name = pretty_model(mb.get("modelName", "?"))
            m = models.setdefault(
                name,
                {"model": name, "cost": 0.0, "input": 0, "output": 0, "cacheRead": 0, "cacheCreate": 0},
            )
            m["cost"] += mb.get("cost", 0.0)
            m["input"] += mb.get("inputTokens", 0)
            m["output"] += mb.get("outputTokens", 0)
            m["cacheRead"] += mb.get("cacheReadTokens", 0)
            m["cacheCreate"] += mb.get("cacheCreationTokens", 0)
    return sorted(models.values(), key=lambda x: x["cost"], reverse=True)


def pretty_model(name: str) -> str:
    """claude-opus-4-8 -> Opus 4.8; claude-haiku-4-5-20251001 -> Haiku 4.5."""
    n = name.replace("claude-", "")
    for family in ("opus", "sonnet", "haiku"):
        if n.startswith(family):
            rest = n[len(family) :].strip("-")
            ver = rest.split("-")[0]  # drop date suffix
            ver = ver.replace("-", ".") if ver else ""
            return f"{family.capitalize()} {ver}".strip()
    return name

# --------------------------------------------------------------------------- #
# Formatting
# --------------------------------------------------------------------------- #
def money(amount: float) -> str:
    if amount == 0:
        return "$0.00"
    if abs(amount) < 0.01:
        return f"${amount:.4f}"
    return f"${amount:,.2f}"


def toks(qty: float) -> str:
    """Compact token count: 1_828_256 -> 1.83M, 71_309 -> 71.3K."""
    if qty == 0:
        return "—"
    if qty >= 1_000_000:
        return f"{qty / 1_000_000:.2f}M"
    if qty >= 1_000:
        return f"{qty / 1_000:.1f}K"
    return f"{qty:,.0f}"


def _esc(s: str) -> str:
    return _html.escape(str(s))

# --------------------------------------------------------------------------- #
# HTML
# --------------------------------------------------------------------------- #
def _stat(label: str, value: str, accent: str = "#e8eaed") -> str:
    return (
        '<td style="padding:10px 16px;background:#232427;border-radius:8px;text-align:center">'
        f'<div style="color:#9aa0a6;font-size:11px;text-transform:uppercase;letter-spacing:.5px">{label}</div>'
        f'<div style="color:{accent};font-size:22px;font-weight:600;margin-top:4px">{value}</div></td>'
    )


def build_html(ctx: dict) -> str:
    headline = (
        '<table style="border-spacing:10px 0;width:100%"><tr>'
        + _stat(f"Cost ({ctx['window']}d)", money(ctx["total_cost"]), "#6cb6ff")
        + _stat("Total tokens", toks(ctx["total_tokens"]))
        + _stat("Avg / day", money(ctx["avg_cost"]), "#f5b942")
        + "</tr></table>"
    )

    # Per-day table (most recent first).
    drows = []
    for d in reversed(ctx["days"]):
        models = ", ".join(pretty_model(m) for m in d.get("modelsUsed", []))
        drows.append(
            f'<tr><td style="padding:6px 12px;border-bottom:1px solid #2c2e33">{_esc(d["period"])}</td>'
            f'<td style="padding:6px 12px;border-bottom:1px solid #2c2e33;text-align:right">{money(d.get("totalCost", 0))}</td>'
            f'<td style="padding:6px 12px;border-bottom:1px solid #2c2e33;text-align:right;color:#9aa0a6">{toks(d.get("totalTokens", 0))}</td>'
            f'<td style="padding:6px 12px;border-bottom:1px solid #2c2e33;text-align:right;color:#9aa0a6">{toks(d.get("outputTokens", 0))}</td>'
            f'<td style="padding:6px 12px;border-bottom:1px solid #2c2e33;color:#9aa0a6;font-size:12px">{_esc(models)}</td></tr>'
        )
    day_table = (
        '<h3 style="margin:24px 0 6px;color:#e8eaed;font-size:15px">By day</h3>'
        '<table style="width:100%;border-collapse:collapse;font-size:13px">'
        '<tr><th style="text-align:left;padding:6px 12px;color:#9aa0a6;font-weight:500">Date</th>'
        '<th style="text-align:right;padding:6px 12px;color:#9aa0a6;font-weight:500">Cost</th>'
        '<th style="text-align:right;padding:6px 12px;color:#9aa0a6;font-weight:500">Total tok</th>'
        '<th style="text-align:right;padding:6px 12px;color:#9aa0a6;font-weight:500">Output tok</th>'
        '<th style="text-align:left;padding:6px 12px;color:#9aa0a6;font-weight:500">Models</th></tr>'
        + "".join(drows)
        + "</table>"
    )

    # By-model table (aggregated over window).
    mrows = []
    for m in ctx["models"]:
        mrows.append(
            f'<tr><td style="padding:6px 12px;border-bottom:1px solid #2c2e33">{_esc(m["model"])}</td>'
            f'<td style="padding:6px 12px;border-bottom:1px solid #2c2e33;text-align:right">{money(m["cost"])}</td>'
            f'<td style="padding:6px 12px;border-bottom:1px solid #2c2e33;text-align:right;color:#9aa0a6">{toks(m["input"])}</td>'
            f'<td style="padding:6px 12px;border-bottom:1px solid #2c2e33;text-align:right;color:#9aa0a6">{toks(m["output"])}</td>'
            f'<td style="padding:6px 12px;border-bottom:1px solid #2c2e33;text-align:right;color:#9aa0a6">{toks(m["cacheRead"])}</td>'
            f'<td style="padding:6px 12px;border-bottom:1px solid #2c2e33;text-align:right;color:#9aa0a6">{toks(m["cacheCreate"])}</td></tr>'
        )
    model_table = (
        f'<h3 style="margin:24px 0 6px;color:#e8eaed;font-size:15px">By model ({ctx["window"]}d)</h3>'
        '<table style="width:100%;border-collapse:collapse;font-size:13px">'
        '<tr><th style="text-align:left;padding:6px 12px;color:#9aa0a6;font-weight:500">Model</th>'
        '<th style="text-align:right;padding:6px 12px;color:#9aa0a6;font-weight:500">Cost</th>'
        '<th style="text-align:right;padding:6px 12px;color:#9aa0a6;font-weight:500">Input</th>'
        '<th style="text-align:right;padding:6px 12px;color:#9aa0a6;font-weight:500">Output</th>'
        '<th style="text-align:right;padding:6px 12px;color:#9aa0a6;font-weight:500">Cache read</th>'
        '<th style="text-align:right;padding:6px 12px;color:#9aa0a6;font-weight:500">Cache create</th></tr>'
        + "".join(mrows)
        + "</table>"
    )

    busiest = ctx.get("busiest")
    busiest_note = (
        f'<p style="color:#9aa0a6;margin:4px 0">Busiest day: <b style="color:#d7dade">'
        f'{_esc(busiest["period"])}</b> at {money(busiest["totalCost"])} '
        f'({toks(busiest["totalTokens"])} tokens).</p>'
        if busiest
        else ""
    )

    return f"""<html><head><meta name="color-scheme" content="dark"><style>html,body{{margin:0;background:#1b1b1d}}</style></head>
<body style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;font-size:14px;color:#d7dade;background:#1b1b1d;padding:18px">
<p style="color:#9aa0a6;margin-top:0">Claude Code usage · last {ctx["window"]} days ({_esc(ctx["since_label"])} – {_esc(ctx["until_label"])}) · generated {ctx["generated"]}</p>
{headline}
{busiest_note}
{day_table}
{model_table}
<hr style="border:none;border-top:1px solid #33353a;margin:22px 0">
<p style="font-size:11px;color:#5f6571">Source: <code>ccusage daily</code> over local ~/.claude logs. Cost is an estimate at public API rates — not your subscription bill. Most tokens are cache reads (cheap) inherent to how Claude Code re-sends context each turn.</p>
</body></html>"""

# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #
def main() -> int:
    today = datetime.now(IST).date()
    since_date = today - timedelta(days=WINDOW_DAYS - 1)
    since = since_date.strftime("%Y%m%d")

    try:
        payload = fetch_usage(since)
    except Exception as e:  # noqa: BLE001 - report and exit non-zero
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

    days = payload.get("daily", [])
    totals = payload.get("totals", {})
    if not days:
        print("No Claude Code usage in window; skipping email.")
        return 0

    total_cost = totals.get("totalCost", sum(d.get("totalCost", 0) for d in days))
    total_tokens = totals.get("totalTokens", sum(d.get("totalTokens", 0) for d in days))
    busiest = max(days, key=lambda d: d.get("totalCost", 0))
    today_cost = next((d.get("totalCost", 0) for d in days if d.get("period") == today.isoformat()), 0.0)

    ctx = {
        "window": WINDOW_DAYS,
        "since_label": days[0].get("period", since_date.isoformat()),
        "until_label": days[-1].get("period", today.isoformat()),
        "generated": datetime.now(IST).strftime("%d %b %H:%M IST"),
        "total_cost": total_cost,
        "total_tokens": total_tokens,
        "avg_cost": total_cost / len(days) if days else 0.0,
        "days": days,
        "models": aggregate_models(days),
        "busiest": busiest,
    }

    subject = (
        f"Claude Code usage — {money(total_cost)} ({WINDOW_DAYS}d) · "
        f"{money(today_cost)} today · busiest {busiest['period']} {money(busiest['totalCost'])}"
    )

    ok = mailpit.push(
        subject,
        sender=f"Claude Code Usage <{MAIL_FROM}>",
        body=(
            f"Last {WINDOW_DAYS} days: {money(total_cost)} / {toks(total_tokens)} tokens "
            f"(est. at API rates). View HTML in Mailpit for the per-day and per-model tables."
        ),
        html=build_html(ctx),
        recipient=MAIL_TO,
    )
    if not ok:
        print("ERROR: Mailpit send failed", file=sys.stderr)
        return 1

    print(f"Sent ccusage digest -> {MAIL_TO} ({WINDOW_DAYS}d {money(total_cost)}, {toks(total_tokens)} tokens)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
