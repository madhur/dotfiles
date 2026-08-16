# Star History Chart Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the broken external `api.star-history.com` README badge with a self-hosted chart: a new weekly script fetches stargazer data via the authenticated `gh` CLI and renders a static PNG committed into the dotfiles repo.

**Architecture:** One new script, `~/scripts/star_history_digest.py` (pure `python-rsha` venv, no new deps — `matplotlib`/`pandas`/`requests` already installed there), separates pure logic (parsing timestamps, building the cumulative series — unit tested) from I/O (the `gh api` subprocess call, the matplotlib file write — exercised via manual/integration verification, matching this repo's existing `*_digest.py` test convention). It's wired into `~/scripts/every_week.sh` right before the existing `gulp backup-and-push` step, so the weekly commit+push that already runs picks up the new/changed PNG with no new git logic. `README.md`'s badge is swapped for a plain `<img>` pointing at the committed file.

**Tech Stack:** Python 3 (`~/.virtualenvs/python-rsha`), `matplotlib`, `gh` CLI (already authenticated), bash (`every_week.sh`), plain assert-based test runner (this repo's convention — see `~/scripts/tests/test_vnstat_digest.py`).

## Global Constraints

- Script must be runnable as `~/scripts/star_history_digest.py` directly (shebang `#!/home/madhur/.virtualenvs/python-rsha/bin/python`, mode 755) — matches how `firefly_digest.py` / `loan_prepayment_digest.py` are invoked from `every_week.sh` (no explicit `python` prefix in the wrapper command).
- Chart covers `madhur/dotfiles` only (confirmed scope — no multi-repo support).
- Single light-background PNG only — no dark-mode variant (confirmed style choice).
- On any fetch/parse failure or zero stargazers, the script MUST exit non-zero and MUST NOT touch the existing `screenshots/star-history.png` — a failed run silently keeps last week's chart rather than blanking the README.
- Output path: `/home/madhur/gitpersonal/dotfiles/screenshots/star-history.png` (repo already has other committed screenshots at this path).
- No Mailpit/`homelab` integration needed — this script doesn't send email, so unlike `vnstat_digest.py`/`firefly_digest.py` it has no `homelab.clients.mailpit` or `set_source()` dependency. Success/failure reporting is handled entirely by `run_with_notification`'s existing ntfy integration in `every_week.sh`.
- `gh api --paginate ... --jq '.[].starred_at'` was verified live against the real repo: returns one unquoted ISO-8601 UTC timestamp per line (format `%Y-%m-%dT%H:%M:%SZ`), total line count (118) matched `gh api repos/madhur/dotfiles --jq .stargazers_count` (118) exactly, confirming pagination is complete and correct.

---

### Task 1: `star_history_digest.py` — fetch, parse, render

**Files:**
- Create: `/home/madhur/scripts/star_history_digest.py`
- Create: `/home/madhur/scripts/tests/test_star_history_digest.py`

**Interfaces:**
- Produces (consumed by Task 2's `every_week.sh` wiring, and by manual verification in Task 3):
  - `star_history_digest.main() -> int` — exit code 0 on success, 1 on failure. Run as `__main__` via the script's shebang.
  - Writes `/home/madhur/gitpersonal/dotfiles/screenshots/star-history.png` on success only.
  - Prints `star_history_digest: wrote <path> (<N> stars)` to stdout on success, `star_history_digest: FAILED - <reason>` to stderr on failure.

- [ ] **Step 1: Write the failing tests for the pure logic**

Create `/home/madhur/scripts/tests/test_star_history_digest.py`:

```python
#!/usr/bin/env python3
"""Unit tests for star_history_digest.py.

Plain assert-based tests, PASS/FAIL runner — same convention as
tests/test_vnstat_digest.py. Run directly:
python3 ~/scripts/tests/test_star_history_digest.py

Pure-logic functions only (parse_and_sort, cumulative_series) are tested
here — no live `gh api` calls. render_chart is smoke-tested (file gets
written) but not asserted on pixel content. Importing star_history_digest
is safe: its module-level code defines constants only, no network/file
calls until main() runs.
"""
import sys
import tempfile
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import star_history_digest as shd

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


# Fixture: real starred_at lines as returned by
# `gh api --paginate repos/madhur/dotfiles/stargazers
#   -H 'Accept: application/vnd.github.star+json' --jq '.[].starred_at'`
# (captured 2026-08-16) — one unquoted ISO-8601 UTC timestamp per line,
# NOT guaranteed sorted by the API.
RAW_LINES_FIXTURE = [
    "2023-06-03T16:30:30Z",
    "2023-02-04T10:37:55Z",
    "2023-07-14T17:31:40Z",
]


def test_parse_and_sort_sorts_ascending():
    result = shd.parse_and_sort(RAW_LINES_FIXTURE)
    assert result == [
        datetime(2023, 2, 4, 10, 37, 55),
        datetime(2023, 6, 3, 16, 30, 30),
        datetime(2023, 7, 14, 17, 31, 40),
    ], result


def test_parse_and_sort_empty_input():
    assert shd.parse_and_sort([]) == []


def test_cumulative_series_counts_up():
    timestamps = shd.parse_and_sort(RAW_LINES_FIXTURE)
    xs, ys = shd.cumulative_series(timestamps)
    assert xs == timestamps
    assert ys == [1, 2, 3], ys


def test_cumulative_series_empty_input():
    xs, ys = shd.cumulative_series([])
    assert xs == []
    assert ys == []


def test_render_chart_writes_file():
    timestamps = shd.parse_and_sort(RAW_LINES_FIXTURE)
    xs, ys = shd.cumulative_series(timestamps)
    with tempfile.TemporaryDirectory() as tmpdir:
        out = Path(tmpdir) / "nested" / "star-history.png"
        shd.render_chart(xs, ys, out, repo="madhur/dotfiles")
        assert out.exists()
        assert out.stat().st_size > 0


if __name__ == "__main__":
    run_test("parse_and_sort sorts ascending", test_parse_and_sort_sorts_ascending)
    run_test("parse_and_sort handles empty input", test_parse_and_sort_empty_input)
    run_test("cumulative_series counts up", test_cumulative_series_counts_up)
    run_test("cumulative_series handles empty input", test_cumulative_series_empty_input)
    run_test("render_chart writes file (creates parent dirs)", test_render_chart_writes_file)
    print(f"\n{FAILURES} failure(s)" if FAILURES else "\nAll tests passed")
    sys.exit(1 if FAILURES else 0)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 ~/scripts/tests/test_star_history_digest.py`
Expected: `ModuleNotFoundError: No module named 'star_history_digest'` (the module doesn't exist yet).

- [ ] **Step 3: Write `star_history_digest.py`**

Create `/home/madhur/scripts/star_history_digest.py`:

```python
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
```

- [ ] **Step 4: Make it executable**

Run: `chmod 755 /home/madhur/scripts/star_history_digest.py`

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python3 ~/scripts/tests/test_star_history_digest.py`
Expected: all 5 `PASS:` lines, then `All tests passed`, exit code 0.

- [ ] **Step 6: No separate commit here**

Confirmed: `~/scripts` is not its own git repo (`git -C ~/scripts rev-parse --is-inside-work-tree` fails with "not a git repository"). `backup.sh:71` (`rsync -avh --delete ~/scripts ./home/madhur/`) mirrors the whole directory into the dotfiles repo at `home/madhur/scripts/` every time `gulp backup-and-push` runs — that's the same mechanism that already produced commits like `fd34ac1 chore: sync every_three_hours.sh`. These two new files reach git for the first time in Task 3's `gulp backup-and-push` run, alongside the README/PNG changes and Task 2's `every_week.sh` edit — one commit, not three.

---

### Task 2: Wire into `every_week.sh`

**Files:**
- Modify: `/home/madhur/scripts/every_week.sh`

**Interfaces:**
- Consumes: `star_history_digest.py`'s exit-code contract from Task 1 (0 = success/wrote PNG, 1 = failure/left PNG untouched) and its shebang-executable convention (invoked directly, no `python` prefix — matches the existing `firefly_digest.py`/`loan_prepayment_digest.py` lines in this same file).

- [ ] **Step 1: Add the new weekly step before `gulp backup-and-push`**

In `/home/madhur/scripts/every_week.sh`, insert a new line immediately before the existing `run_with_notification "cd /home/madhur/gitpersonal/dotfiles && node_modules/gulp-cli/bin/gulp.js backup-and-push" ...` line, so the chart is regenerated before the weekly commit+push picks it up:

```bash
run_with_notification "/home/madhur/scripts/star_history_digest.py" "Star History Chart" "weekly"
run_with_notification "cd /home/madhur/gitpersonal/dotfiles && node_modules/gulp-cli/bin/gulp.js backup-and-push" "Dotfiles update and push" "weekly" "false" "true" "false"
```

- [ ] **Step 2: Verify the script is syntactically valid bash**

Run: `bash -n /home/madhur/scripts/every_week.sh`
Expected: no output, exit code 0.

- [ ] **Step 3: Manually run the new line standalone to confirm it works inside the wrapper**

Run: `bash -c 'source /home/madhur/scripts/notify_wrapper.sh; export NOTIFY_ON_SUCCESS=true; run_with_notification "/home/madhur/scripts/star_history_digest.py" "Star History Chart" "weekly"'`
Expected: `[timestamp] Starting: Star History Chart`, then `star_history_digest: wrote /home/madhur/gitpersonal/dotfiles/screenshots/star-history.png (118 stars)` (star count will have grown since this plan was written — that's fine), then a completion line from the wrapper. Confirm `git -C /home/madhur/gitpersonal/dotfiles status --short screenshots/star-history.png` shows the file as new/modified.

- [ ] **Step 4: No separate commit here**

Same as Task 1 Step 6: `~/scripts` isn't its own git repo. This edit reaches git in Task 3's `gulp backup-and-push` run via `backup.sh`'s mirror of `~/scripts` into `home/madhur/scripts/`.

---

### Task 3: README swap + first committed chart + failure-path verification

**Files:**
- Modify: `/home/madhur/gitpersonal/dotfiles/README.md`
- Create (generated by Task 1's script, committed here): `/home/madhur/gitpersonal/dotfiles/screenshots/star-history.png`

**Interfaces:**
- Consumes: the PNG already written to `screenshots/star-history.png` by Task 2 Step 3's manual run.

- [ ] **Step 1: Replace the badge in `README.md`**

In `/home/madhur/gitpersonal/dotfiles/README.md`, replace:

```md
## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=madhur/dotfiles&type=date&legend=top-left)](https://www.star-history.com/#madhur/dotfiles&type=date&legend=top-left)
```

with:

```md
## Star History

<img alt="Star History Chart" src="https://raw.githubusercontent.com/madhur/dotfiles/master/screenshots/star-history.png" />
```

- [ ] **Step 2: Confirm the chart file already exists from Task 2's manual run**

Run: `ls -la /home/madhur/gitpersonal/dotfiles/screenshots/star-history.png`
Expected: file exists, non-zero size, mtime from Task 2 Step 3.

If it doesn't exist (Task 2 Step 3 was skipped), run it now: `/home/madhur/scripts/star_history_digest.py`

- [ ] **Step 3: Verify the failure path doesn't clobber the chart**

Confirm the current file's checksum, then run the script against a repo that will make `gh api` fail (a nonexistent repo), and confirm the real chart is untouched:

Note: reassigning `shd.REPO` after import does NOT affect `fetch_starred_at`'s default argument (Python binds default values at function-definition time) — monkeypatch the function itself instead, as below.

```bash
cd /home/madhur/gitpersonal/dotfiles
md5sum screenshots/star-history.png > /tmp/before.md5
python3 -c "
import sys
sys.path.insert(0, '/home/madhur/scripts')
import star_history_digest as shd

def _boom():
    raise RuntimeError('simulated gh api failure')

shd.fetch_starred_at = _boom
sys.exit(shd.main())
"
echo "exit code: $?"
md5sum -c /tmp/before.md5
```

Expected: `star_history_digest: FAILED - gh api failed ...` on stderr, `exit code: 1`, and `md5sum -c` reports `screenshots/star-history.png: OK` (unchanged).

- [ ] **Step 4: View the rendered chart locally**

Open `/home/madhur/gitpersonal/dotfiles/screenshots/star-history.png` (e.g. via the Read tool or an image viewer) and confirm it looks like a reasonable ascending step chart, title reads "madhur/dotfiles star history", axes labeled "Date"/"Stars".

- [ ] **Step 5: Run the real weekly commit+push task**

Note: `git status` may already show an unrelated pending edit to
`gulpfile.js` (a pre-existing local change, not introduced by this plan).
That's expected — `gitadd` runs `git add .`, so it'll ride along in the same
commit exactly as it would on any normal Sunday run of `every_week.sh`; no
action needed.

This is the same command `every_week.sh` runs, and the one place all of this
plan's filesystem changes actually reach git: `backup.sh` (via the `backup`
gulp task) mirrors `~/scripts` into `home/madhur/scripts/` (picking up
Task 1's new `star_history_digest.py` + `tests/test_star_history_digest.py`
and Task 2's `every_week.sh` edit), then `git add . && git commit
(LLM-generated message) && git push` (via the `git` gulp task) stages and
pushes everything — README.md, screenshots/star-history.png, and the
mirrored scripts — in one commit.

```bash
cd /home/madhur/gitpersonal/dotfiles
node_modules/gulp-cli/bin/gulp.js backup-and-push
```

Expected: verbose task output for `backup`, `gitadd`, `gitcommit` (prints
the generated commit message), `gitpush`. Confirm with `git log -1 --stat`
that the commit includes `README.md`, `screenshots/star-history.png` (repo
root, alongside `keybindings.png` etc. — NOT under `home/madhur/`),
`home/madhur/scripts/star_history_digest.py`,
`home/madhur/scripts/tests/test_star_history_digest.py`, and
`home/madhur/scripts/every_week.sh`.

- [ ] **Step 6: Confirm the image renders on GitHub**

Load `https://github.com/madhur/dotfiles` (or
`https://raw.githubusercontent.com/madhur/dotfiles/master/screenshots/star-history.png`
directly) in a browser and confirm the chart displays instead of a
broken-image icon.
