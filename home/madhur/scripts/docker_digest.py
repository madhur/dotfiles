#!/home/madhur/.virtualenvs/python-rsha/bin/python
"""Docker homelab daily digest -> Mailpit.

Emails a snapshot of the local Docker engine and the ~/docker compose tree:
running-container count, the containers and images eating the most disk, what
`docker system df` reports as reclaimable, per-stack disk usage under ~/docker,
and a callout for anything stopped or unhealthy.

Sibling of the firefly / bookstack / ccusage digests — same shape: shared
homelab Mailpit client (every send surfaces in Prometheus as service=mailpit,
source=docker_digest), the dark HTML template helpers, and a *-digest.env
sidecar. Invoked daily from ~/scripts/every_24_hours.sh.

Notes baked in from this homelab:
  - Stacks are docker-compose projects; each lives in a ~/docker/<name> folder.
    The compose project label on a container maps it back to that folder.
  - Container data dirs are mostly root-owned (uid 999 / root), so per-stack
    sizing shells out to `sudo -n du` (passwordless sudo is configured for du).
  - Sizes from the docker CLI are decimal (kB/MB/GB = 1000-based); we parse them
    to bytes for sorting and re-humanize for display.

Config (override via docker-digest.env):
  MAIL_FROM        (default docker-digest@madhur.co.in)
  MAIL_TO          (default ahuja.madhur@gmail.com)
  DOCKER_ROOT      (default /home/madhur/docker)
  TOP_N            (default 5)
  SEND_WHEN_EMPTY  (default true)
"""

from __future__ import annotations

import html as _html
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

from dotenv import load_dotenv

from homelab import set_source
from homelab.clients import mailpit

set_source("docker_digest")

SCRIPT_DIR = Path(__file__).resolve().parent
load_dotenv(SCRIPT_DIR / "docker-digest.env")

MAIL_FROM = os.environ.get("MAIL_FROM", "docker-digest@madhur.co.in")
MAIL_TO = os.environ.get("MAIL_TO", "ahuja.madhur@gmail.com")
DOCKER_ROOT = Path(os.environ.get("DOCKER_ROOT", "/home/madhur/docker"))
TOP_N = int(os.environ.get("TOP_N", "5"))
SEND_WHEN_EMPTY = os.environ.get("SEND_WHEN_EMPTY", "true").lower() == "true"

IST = timezone(timedelta(hours=5, minutes=30))

# Folders under DOCKER_ROOT that aren't stacks.
SKIP_DIRS = {".git", ".claude", "export", "archive"}

# --------------------------------------------------------------------------- #
# Size parsing / formatting (docker CLI uses decimal units)
# --------------------------------------------------------------------------- #
_UNITS = {
    "B": 1, "KB": 1_000, "KIB": 1_024, "MB": 1_000_000, "MIB": 1_048_576,
    "GB": 1_000_000_000, "GIB": 1_073_741_824, "TB": 1_000_000_000_000,
    "TIB": 1_099_511_627_776, "PB": 1_000_000_000_000_000,
}
_SIZE_RE = re.compile(r"([0-9.]+)\s*([A-Za-z]+)")


def to_bytes(s: str | None) -> int:
    """Parse a docker size string ("1.564GB", "391.2MB", "0B") to bytes."""
    if not s:
        return 0
    m = _SIZE_RE.search(s)
    if not m:
        return 0
    val, unit = m.group(1), m.group(2).upper()
    return int(float(val) * _UNITS.get(unit, 1))


def human(n: int) -> str:
    """Bytes -> short decimal string (matches docker's style)."""
    f = float(n)
    for unit in ("B", "kB", "MB", "GB", "TB"):
        if f < 1000 or unit == "TB":
            return f"{f:.0f} {unit}" if unit == "B" else f"{f:.1f} {unit}"
        f /= 1000
    return f"{f:.1f} TB"


# --------------------------------------------------------------------------- #
# Data gathering
# --------------------------------------------------------------------------- #
def _docker_json(args: list[str]) -> list[dict]:
    """Run a docker command emitting one JSON object per line; parse to list."""
    out = subprocess.run(
        ["docker", *args, "--format", "{{json .}}"],
        capture_output=True, text=True, check=True,
    ).stdout
    return [json.loads(line) for line in out.splitlines() if line.strip()]


def _stack_of(labels: str) -> str:
    """Pull the compose project name out of a container's Labels string."""
    m = re.search(r"com\.docker\.compose\.project=([^,]+)", labels or "")
    return m.group(1) if m else "—"


def gather() -> dict:
    containers = _docker_json(["ps", "-a"])
    images = _docker_json(["images"])
    df = {row["Type"]: row for row in _docker_json(["system", "df"])}

    enriched = [{
        "name": c.get("Names", "?"),
        "stack": _stack_of(c.get("Labels", "")),
        "image": c.get("Image", "?"),
        "state": c.get("State", "?"),
        "status": c.get("Status", ""),
        "health": (c.get("HealthStatus") or "").strip(),
    } for c in containers]

    running = [c for c in enriched if c["state"] == "running"]
    stopped = [c for c in enriched if c["state"] != "running"]
    unhealthy = [c for c in enriched
                 if c["health"] == "unhealthy" or "(unhealthy)" in c["status"]]

    img_rows =[{"repo": f'{i.get("Repository", "?")}:{i.get("Tag", "?")}',
                 "size": to_bytes(i.get("Size")),
                 "containers": i.get("Containers", "0"),
                 "dangling": i.get("Repository") == "<none>"}
                for i in images]
    top_images = sorted(img_rows, key=lambda i: i["size"], reverse=True)[:TOP_N]
    dangling = [i for i in img_rows if i["dangling"]]

    return {
        "containers_total": len(enriched),
        "running": running,
        "stopped": stopped,
        "unhealthy": unhealthy,
        "top_images": top_images,
        "dangling_count": len(dangling),
        "dangling_size": sum(i["size"] for i in dangling),
        "df": df,
        "stacks": stack_sizes(),
    }


def stack_sizes() -> list[dict]:
    """`sudo -n du` each immediate subfolder of DOCKER_ROOT -> sorted by size."""
    if not DOCKER_ROOT.is_dir():
        return []
    dirs = sorted(p for p in DOCKER_ROOT.iterdir()
                  if p.is_dir() and p.name not in SKIP_DIRS)
    if not dirs:
        return []
    try:
        out = subprocess.run(
            ["sudo", "-n", "du", "-sxB1", *(str(p) for p in dirs)],
            capture_output=True, text=True,
        ).stdout
    except Exception:  # noqa: BLE001
        return []
    rows = []
    for line in out.splitlines():
        parts = line.split("\t", 1)
        if len(parts) == 2 and parts[0].isdigit():
            rows.append({"name": Path(parts[1].strip()).name,
                         "size": int(parts[0])})
    rows.sort(key=lambda r: r["size"], reverse=True)
    return rows

# --------------------------------------------------------------------------- #
# HTML (same helpers as the firefly / bookstack digests)
# --------------------------------------------------------------------------- #
def _esc(s) -> str:
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


def build_html(ctx: dict, d: dict) -> str:
    df = d["df"]
    img_df = df.get("Images", {})
    vol_df = df.get("Local Volumes", {})
    reclaimable = sum(to_bytes(row.get("Reclaimable")) for row in df.values())

    headline = (
        '<table style="border-spacing:10px 0;width:100%"><tr>'
        + _stat("Running", str(len(d["running"])), "#81c995")
        + _stat("Images", img_df.get("Size", "—"), "#6cb6ff")
        + _stat("Volumes", vol_df.get("Size", "—"), "#6cb6ff")
        + _stat("Reclaimable", human(reclaimable),
                "#f5b942" if reclaimable else "#81c995")
        + "</tr></table>"
    )

    # Stopped / unhealthy callout.
    alert = ""
    if d["unhealthy"]:
        rows = [f'<tr>{_cell(_esc(c["name"]))}{_cell(_esc(c["stack"]), "left", "#9aa0a6")}'
                f'{_cell(_esc(c["status"]), "left", "#f28b82")}</tr>' for c in d["unhealthy"]]
        alert += _table("🚑 Unhealthy",
                        [("Container", "left"), ("Stack", "left"), ("Status", "left")], rows)
    if d["stopped"]:
        rows = [f'<tr>{_cell(_esc(c["name"]))}{_cell(_esc(c["stack"]), "left", "#9aa0a6")}'
                f'{_cell(_esc(c["status"]), "left", "#9aa0a6")}</tr>' for c in d["stopped"]]
        alert += _table(f'⏹️ Not running ({len(d["stopped"])})',
                        [("Container", "left"), ("Stack", "left"), ("Status", "left")], rows)
    if not d["stopped"] and not d["unhealthy"]:
        alert = ('<p style="color:#81c995;margin:18px 0 0;font-size:13px">'
                 f'✓ All {len(d["running"])} containers running and healthy.</p>')

    # Per-stack folder usage under DOCKER_ROOT (the real disk truth — bind mounts).
    s_rows = [
        f'<tr>{_cell(_esc(s["name"]))}{_cell(human(s["size"]), "right")}</tr>'
        for s in d["stacks"][:TOP_N]
    ]
    stack_total = sum(s["size"] for s in d["stacks"])
    s_table = _table(
        f"💾 Top {TOP_N} stacks by folder size",
        [("Stack", "left"), ("Size", "right")],
        s_rows,
        note=(f'{len(d["stacks"])} stacks, {human(stack_total)} total under '
              f'{DOCKER_ROOT}.') if d["stacks"] else "",
    )

    # Top images by size.
    i_rows = [
        f'<tr>{_cell(_esc(i["repo"]))}'
        f'{_cell(_esc(i["containers"]), "right", "#9aa0a6")}'
        f'{_cell(human(i["size"]), "right")}</tr>'
        for i in d["top_images"]
    ]
    dangling_note = (f'{d["dangling_count"]} dangling image(s) totalling '
                     f'{human(d["dangling_size"])}.') if d["dangling_count"] else ""
    i_table = _table(
        f"🖼️ Top {TOP_N} images by size",
        [("Repository:Tag", "left"), ("In use", "right"), ("Size", "right")],
        i_rows, note=dangling_note,
    )

    # docker system df breakdown.
    df_rows = [
        f'<tr>{_cell(_esc(t))}{_cell(_esc(r.get("TotalCount", "?")), "right", "#9aa0a6")}'
        f'{_cell(_esc(r.get("Active", "?")), "right", "#9aa0a6")}'
        f'{_cell(_esc(r.get("Size", "?")), "right")}'
        f'{_cell(_esc(r.get("Reclaimable", "?")), "right", "#f5b942")}</tr>'
        for t, r in df.items()
    ]
    df_table = _table(
        "🧮 docker system df",
        [("Type", "left"), ("Total", "right"), ("Active", "right"),
         ("Size", "right"), ("Reclaimable", "right")],
        df_rows,
        note="`docker system prune` would reclaim the dangling/unused portion.",
    )

    return f"""<html><head><meta name="color-scheme" content="dark"><style>html,body{{margin:0;background:#1b1b1d}}</style></head>
<body style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;font-size:14px;color:#d7dade;background:#1b1b1d;padding:18px">
<p style="color:#9aa0a6;margin-top:0">Docker homelab · {ctx["day_label"]} · generated {ctx["generated"]}</p>
{headline}
{alert}
{s_table}
{i_table}
{df_table}
<hr style="border:none;border-top:1px solid #33353a;margin:22px 0">
<p style="font-size:11px;color:#5f6571">Container/image sizes from the docker CLI (decimal units). Per-stack sizes via `sudo du` over {DOCKER_ROOT}; bind-mount data lives here, named volumes live under /var/lib/docker.</p>
</body></html>"""

# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #
def main() -> int:
    try:
        d = gather()
    except FileNotFoundError:
        print("ERROR: docker CLI not found", file=sys.stderr)
        return 1
    except subprocess.CalledProcessError as e:
        print(f"ERROR: docker command failed: {e.stderr or e}", file=sys.stderr)
        return 1

    noteworthy = bool(d["stopped"] or d["unhealthy"] or d["dangling_count"])
    if not noteworthy and not SEND_WHEN_EMPTY:
        print("Nothing noteworthy and SEND_WHEN_EMPTY=false; skipping mail.")
        return 0

    now = datetime.now(IST)
    ctx = {
        "day_label": now.strftime("%A, %d %b %Y"),
        "generated": now.strftime("%d %b %H:%M IST"),
    }

    img_size = d["df"].get("Images", {}).get("Size", "?")
    subject = (f"Docker — {len(d['running'])}/{d['containers_total']} running · "
               f"{img_size} images ({now.strftime('%d %b')})")
    if d["unhealthy"]:
        subject += f" · 🚑{len(d['unhealthy'])} unhealthy"
    elif d["stopped"]:
        subject += f" · ⏹️{len(d['stopped'])} stopped"

    ok = mailpit.push(
        subject,
        sender=f"Docker Digest <{MAIL_FROM}>",
        body=(f"{len(d['running'])}/{d['containers_total']} containers running, "
              f"{img_size} of images. View HTML in Mailpit for the top-disk, "
              "per-stack and reclaimable-space tables."),
        html=build_html(ctx, d),
        recipient=MAIL_TO,
    )
    if not ok:
        print("ERROR: Mailpit send failed", file=sys.stderr)
        return 1

    print(f"Sent Docker digest -> {MAIL_TO} "
          f"({len(d['running'])}/{d['containers_total']} running, "
          f"{len(d['stopped'])} stopped, {len(d['unhealthy'])} unhealthy)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
