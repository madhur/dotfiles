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
