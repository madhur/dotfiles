#!/home/madhur/.virtualenvs/python-rsha/bin/python
"""Star history chart for madhur/dotfiles -> screenshots/star-history.png.

GitHub restricted access to api.star-history.com's unauthenticated star
data scraping, breaking the README's embedded badge for viewers. This
script replaces it: fetch stargazer starred_at timestamps ourselves via
the already-authenticated `gh` CLI (higher rate limit, not subject to that
restriction), render a cumulative stars-over-time PNG with matplotlib, and
write it into the dotfiles repo working tree so the existing weekly
`gulp backup-and-push` step (see every_week.sh) commits+pushes it like any
other changed file — no dedicated git logic here.

Scope: madhur/dotfiles only. Single light-background PNG — no multi-repo,
no dark-mode variant (see docs/superpowers/specs/2026-08-16-star-history-
chart-design.md for the full design rationale).

On any fetch/parse failure or zero stargazers, exits 1 WITHOUT touching
the existing PNG, so a bad run leaves last week's chart in place instead
of blanking the README. Invoked weekly from ~/scripts/every_week.sh via
run_with_notification, which reports success/failure over ntfy — this
script itself has no email/homelab-metrics integration.
"""
from __future__ import annotations

import subprocess
import sys
from datetime import datetime
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.dates as mdates
import matplotlib.pyplot as plt

REPO = "madhur/dotfiles"
OUTPUT_PATH = Path("/home/madhur/gitpersonal/dotfiles/screenshots/star-history.png")
TIMESTAMP_FORMAT = "%Y-%m-%dT%H:%M:%SZ"


# --------------------------------------------------------------------------- #
# Fetch (I/O)
# --------------------------------------------------------------------------- #
def fetch_starred_at(repo: str = REPO) -> list[str]:
    """Run `gh api --paginate` against the stargazers endpoint.

    Returns raw starred_at strings, one per stargazer, in whatever order
    the API returns them (NOT guaranteed sorted — caller must sort).
    Raises RuntimeError if the `gh` call fails.
    """
    result = subprocess.run(
        [
            "gh", "api", "--paginate", f"repos/{repo}/stargazers",
            "-H", "Accept: application/vnd.github.star+json",
            "--jq", ".[].starred_at",
        ],
        capture_output=True, text=True, timeout=120,
    )
    if result.returncode != 0:
        raise RuntimeError(f"gh api failed (exit {result.returncode}): {result.stderr.strip()}")
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


# --------------------------------------------------------------------------- #
# Pure logic
# --------------------------------------------------------------------------- #
def parse_and_sort(raw_lines: list[str]) -> list[datetime]:
    """Parse starred_at strings into ascending-sorted datetimes."""
    timestamps = [datetime.strptime(line, TIMESTAMP_FORMAT) for line in raw_lines]
    return sorted(timestamps)


def cumulative_series(timestamps: list[datetime]) -> tuple[list[datetime], list[int]]:
    """Turn ascending-sorted starred_at timestamps into a cumulative step series.

    ys[i] is the total star count immediately after xs[i]'s star landed.
    """
    xs = timestamps
    ys = list(range(1, len(timestamps) + 1))
    return xs, ys


# --------------------------------------------------------------------------- #
# Render (I/O)
# --------------------------------------------------------------------------- #
def render_chart(xs: list[datetime], ys: list[int], output_path: Path, repo: str = REPO) -> None:
    """Render the cumulative series as a PNG, creating parent dirs as needed."""
    fig, ax = plt.subplots(figsize=(10, 5), facecolor="white")
    ax.step(xs, ys, where="post", color="#0969da", linewidth=2)
    ax.set_title(f"{repo} star history")
    ax.set_xlabel("Date")
    ax.set_ylabel("Stars")
    ax.xaxis.set_major_formatter(mdates.DateFormatter("%Y-%m"))
    ax.grid(True, alpha=0.3)
    fig.autofmt_xdate()
    fig.tight_layout()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_path, dpi=150)
    plt.close(fig)


# --------------------------------------------------------------------------- #
# Entry point
# --------------------------------------------------------------------------- #
def main() -> int:
    try:
        raw_lines = fetch_starred_at()
        if not raw_lines:
            raise RuntimeError("zero stargazers returned")
        timestamps = parse_and_sort(raw_lines)
    except Exception as e:
        print(f"star_history_digest: FAILED - {e}", file=sys.stderr)
        return 1
    xs, ys = cumulative_series(timestamps)
    render_chart(xs, ys, OUTPUT_PATH)
    print(f"star_history_digest: wrote {OUTPUT_PATH} ({len(timestamps)} stars)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
