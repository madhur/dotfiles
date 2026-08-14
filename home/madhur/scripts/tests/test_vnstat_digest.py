#!/usr/bin/env python3
"""Unit tests for vnstat_digest.py.

Plain assert-based tests, PASS/FAIL runner — same convention as
tests/test_loan_prepayment_digest.py. Run directly:
python3 ~/scripts/tests/test_vnstat_digest.py

Pure-logic functions only (extract_traffic, find_day, find_month, human,
derive, build_email) are tested here — no live vnstat/Mailpit calls.
Importing vnstat_digest is safe: its module-level code only loads .env
files and calls set_source(), no network calls until main() runs.
"""
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import vnstat_digest as vd

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


# Fixture: a trimmed-down but real shape of `vnstat -i enp5s0 --json` output
# (captured 2026-08-09; rx/tx values match vnstat's own CLI "7.97 GiB" /
# "5.79 GiB" report for the 2026-08-08 day entry).
RAW_FIXTURE = {
    "vnstatversion": "2.13",
    "jsonversion": "2",
    "interfaces": [{
        "name": "enp5s0",
        "alias": "",
        "created": {"date": {"year": 2026, "month": 8, "day": 8}, "timestamp": 1786202930},
        "updated": {"date": {"year": 2026, "month": 8, "day": 9},
                    "time": {"hour": 15, "minute": 0}, "timestamp": 1786267800},
        "traffic": {
            "total": {"rx": 109096234491, "tx": 104894708838},
            "day": [
                {"id": 72, "date": {"year": 2026, "month": 8, "day": 8},
                 "timestamp": 1786127400, "rx": 8556681323, "tx": 6214523409},
                {"id": 158, "date": {"year": 2026, "month": 8, "day": 9},
                 "timestamp": 1786213800, "rx": 100539553168, "tx": 98680185429},
            ],
            "month": [
                {"id": 72, "date": {"year": 2026, "month": 8},
                 "timestamp": 1785522600, "rx": 109096234491, "tx": 104894708838},
            ],
        },
    }],
}


# Fixture: synthetic ntopng flow records covering the attribution cases
# top_talkers must handle — local->remote, remote->local, local<->local
# (counts for both endpoints), and an unresolved hostname (falls back to
# IP).
FLOW_FIXTURE = [
    {"SRC_ADDR_LOCAL": True, "DST_ADDR_LOCAL": False, "SRC_NAME": "kafka",
     "IPV4_SRC_ADDR": "192.168.1.82", "DST_NAME": "", "IPV4_DST_ADDR": "1.2.3.4",
     "L7_PROTO_NAME": "TLS", "IN_BYTES": 600, "OUT_BYTES": 400},
    {"SRC_ADDR_LOCAL": False, "DST_ADDR_LOCAL": True, "SRC_NAME": "",
     "IPV4_SRC_ADDR": "5.6.7.8", "DST_NAME": "Mac", "IPV4_DST_ADDR": "192.168.1.211",
     "L7_PROTO_NAME": "TLS", "IN_BYTES": 300, "OUT_BYTES": 200},
    {"SRC_ADDR_LOCAL": True, "DST_ADDR_LOCAL": True, "SRC_NAME": "kafka",
     "IPV4_SRC_ADDR": "192.168.1.82", "DST_NAME": "router", "IPV4_DST_ADDR": "192.168.1.1",
     "L7_PROTO_NAME": "HTTP.SOAP", "IN_BYTES": 100, "OUT_BYTES": 100},
    {"SRC_ADDR_LOCAL": True, "DST_ADDR_LOCAL": False, "SRC_NAME": "Mac",
     "IPV4_SRC_ADDR": "192.168.1.211", "DST_NAME": "", "IPV4_DST_ADDR": "9.9.9.9",
     "L7_PROTO_NAME": "BitTorrent", "IN_BYTES": 30, "OUT_BYTES": 20},
    {"SRC_ADDR_LOCAL": True, "DST_ADDR_LOCAL": False, "SRC_NAME": "kafka",
     "IPV4_SRC_ADDR": "192.168.1.82", "IPV4_DST_ADDR": "9.9.9.10",
     "IN_BYTES": 10, "OUT_BYTES": 10},
]


def test_local_device_labels_covers_all_directions():
    assert vd.local_device_labels(FLOW_FIXTURE[0]) == ["kafka"]  # local -> remote
    assert vd.local_device_labels(FLOW_FIXTURE[1]) == ["Mac"]    # remote -> local
    assert vd.local_device_labels(FLOW_FIXTURE[2]) == ["kafka", "router"]  # local <-> local
    assert vd.local_device_labels({"SRC_ADDR_LOCAL": False, "DST_ADDR_LOCAL": False}) == []


def test_parse_flow_lines_skips_non_json_and_blank_lines():
    lines = [
        '{"a": 1}',
        '',
        '   ',
        'not json at all',
        '{"b": 2}',
        '{"broken": ',
    ]
    result = vd.parse_flow_lines(lines)
    assert result == [{"a": 1}, {"b": 2}]


def test_top_talkers_attributes_by_local_side_and_ranks_descending():
    # kafka: 1000 (flow 1) + 200 (flow 3) + 20 (flow 5) = 1220
    # Mac:   500 (flow 2) + 50 (flow 4) = 550
    # router: 200 (flow 3, local<->local counts for both endpoints)
    result = vd.top_talkers(FLOW_FIXTURE)
    assert result == [
        {"label": "kafka", "bytes": 1220},
        {"label": "Mac", "bytes": 550},
        {"label": "router", "bytes": 200},
    ]


def test_top_talkers_falls_back_to_ip_when_name_unresolved():
    flows = [{"SRC_ADDR_LOCAL": True, "DST_ADDR_LOCAL": False, "SRC_NAME": "",
              "IPV4_SRC_ADDR": "192.168.1.50", "IN_BYTES": 100, "OUT_BYTES": 0}]
    result = vd.top_talkers(flows)
    assert result == [{"label": "192.168.1.50", "bytes": 100}]


def test_top_talkers_returns_empty_list_for_no_flows():
    assert vd.top_talkers([]) == []


def test_extract_traffic_finds_matching_interface():
    traffic = vd.extract_traffic(RAW_FIXTURE, "enp5s0")
    assert traffic["total"]["rx"] == 109096234491


def test_extract_traffic_raises_when_interface_missing():
    try:
        vd.extract_traffic(RAW_FIXTURE, "eth9")
        assert False, "expected ValueError"
    except ValueError as e:
        assert "eth9" in str(e)
        assert "enp5s0" in str(e)


def test_find_day_matches_by_date():
    days = RAW_FIXTURE["interfaces"][0]["traffic"]["day"]
    entry = vd.find_day(days, date(2026, 8, 8))
    assert entry["rx"] == 8556681323


def test_find_day_returns_none_when_absent():
    days = RAW_FIXTURE["interfaces"][0]["traffic"]["day"]
    assert vd.find_day(days, date(2026, 1, 1)) is None


def test_find_month_matches_year_and_month():
    months = RAW_FIXTURE["interfaces"][0]["traffic"]["month"]
    entry = vd.find_month(months, 2026, 8)
    assert entry["rx"] == 109096234491


def test_find_month_returns_none_when_absent():
    months = RAW_FIXTURE["interfaces"][0]["traffic"]["month"]
    assert vd.find_month(months, 2025, 1) is None


def test_human_bytes():
    assert vd.human(0) == "0 B"
    assert vd.human(500) == "500 B"


def test_human_kib_mib_gib():
    assert vd.human(1024) == "1.00 KiB"
    assert vd.human(1024 * 1024) == "1.00 MiB"
    # Real fixture value: vnstat's own CLI reports this exact byte count as "7.97 GiB".
    assert vd.human(8556681323) == "7.97 GiB"


def test_derive_picks_yesterday_and_month_and_rows():
    traffic = vd.extract_traffic(RAW_FIXTURE, "enp5s0")
    result = vd.derive(traffic, today=date(2026, 8, 9))
    assert result["yesterday"]["rx"] == 8556681323
    assert result["month"]["rx"] == 109096234491
    assert len(result["rows"]) == 2
    assert result["rows"][0]["date"] == date(2026, 8, 9)  # most recent first
    assert result["rows"][0]["is_today"] is True
    assert result["rows"][1]["is_today"] is False
    assert result["rows"][0]["total"] == 100539553168 + 98680185429


def test_derive_month_to_date_excludes_days_from_other_months():
    traffic = {
        "day": [
            {"date": {"year": 2026, "month": 7, "day": 31}, "rx": 1, "tx": 1},
            {"date": {"year": 2026, "month": 8, "day": 1}, "rx": 2, "tx": 2},
            {"date": {"year": 2026, "month": 8, "day": 8}, "rx": 8556681323, "tx": 6214523409},
            {"date": {"year": 2026, "month": 8, "day": 9}, "rx": 100539553168, "tx": 98680185429},
        ],
        "month": [{"date": {"year": 2026, "month": 8}, "rx": 109096234491, "tx": 104894708838}],
    }
    result = vd.derive(traffic, today=date(2026, 8, 9))
    # 1, 8, 9 Aug -- the 31 Jul day (previous month) is excluded.
    assert [r["date"] for r in result["rows"]] == [
        date(2026, 8, 9), date(2026, 8, 8), date(2026, 8, 1),
    ]


def test_derive_yesterday_none_when_no_matching_day():
    traffic = vd.extract_traffic(RAW_FIXTURE, "enp5s0")
    result = vd.derive(traffic, today=date(2026, 1, 1))
    assert result["yesterday"] is None
    assert result["month"] is None


def _email_ctx(**overrides):
    base = {
        "iface": "enp5s0",
        "now": date(2026, 8, 9),
        "created": date(2026, 8, 8),
        "yesterday": {"rx": 8556681323, "tx": 6214523409},
        "month": {"rx": 109096234491, "tx": 104894708838},
        "rows": [
            {"date": date(2026, 8, 9), "rx": 100539553168, "tx": 98680185429,
             "total": 100539553168 + 98680185429, "is_today": True},
            {"date": date(2026, 8, 8), "rx": 8556681323, "tx": 6214523409,
             "total": 8556681323 + 6214523409, "is_today": False},
        ],
    }
    base.update(overrides)
    return base


def test_build_email_subject_includes_iface_and_yesterday_totals():
    subject, plain, html = vd.build_email(_email_ctx())
    assert "enp5s0" in subject
    assert "7.97 GiB" in subject  # yesterday rx
    assert "5.79 GiB" in subject  # yesterday tx
    assert "08 Aug" in subject


def test_build_email_subject_no_data_when_yesterday_missing():
    subject, plain, html = vd.build_email(_email_ctx(yesterday=None))
    assert "no data for yesterday" in subject


def test_build_email_plain_includes_month_to_date():
    subject, plain, html = vd.build_email(_email_ctx())
    assert "7.97 GiB" in plain
    assert "Month-to-date" in plain
    assert "199.29 GiB" in plain  # month total: (109096234491+104894708838) bytes


def test_build_email_html_marks_today_row():
    subject, plain, html = vd.build_email(_email_ctx())
    assert "(so far)" in html
    assert "enp5s0" in html


def test_build_email_html_omits_today_marker_when_no_today_row():
    ctx = _email_ctx(rows=[
        {"date": date(2026, 8, 8), "rx": 8556681323, "tx": 6214523409,
         "total": 8556681323 + 6214523409, "is_today": False},
    ])
    _, _, html = vd.build_email(ctx)
    assert "(so far)" not in html


def test_build_email_days_table_titled_month_to_date_with_total_row():
    _, _, html = vd.build_email(_email_ctx())
    assert "Days this month (2)" in html
    assert ">Total<" in html
    assert "199.29 GiB" in html  # month total row (rx+tx), same figure as the headline stat


def _ntopng_ctx():
    return {
        "talkers": [
            {"label": "kafka", "bytes": 2_100_000_000},
            {"label": "Mac", "bytes": 1_400_000_000},
            {"label": "router", "bytes": 300_000_000},
            {"label": "extra1", "bytes": 100},
            {"label": "extra2", "bytes": 50},
        ],
    }


def test_build_email_renders_ntopng_devices_table_when_present():
    ctx = _email_ctx(ntopng=_ntopng_ctx(), top_n=3)
    _, _, html = vd.build_email(ctx)
    assert "Top devices (yesterday)" in html
    assert "kafka" in html
    assert "Mac" in html
    assert "router" in html
    # top_n=3 truncates extra1(100)+extra2(50) -> human(150) = "150 B".
    assert "+2 more, totalling 150 B" in html
    assert "Top applications by device" not in html


def test_build_email_omits_ntopng_table_when_absent():
    ctx = _email_ctx()  # no "ntopng" key at all -> build_email must default via .get()
    _, _, html = vd.build_email(ctx)
    assert "Top devices" not in html


def test_build_email_omits_ntopng_table_when_none():
    ctx = _email_ctx(ntopng=None)
    _, _, html = vd.build_email(ctx)
    assert "Top devices" not in html


if __name__ == "__main__":
    run_test("extract_traffic finds matching interface", test_extract_traffic_finds_matching_interface)
    run_test("extract_traffic raises when interface missing", test_extract_traffic_raises_when_interface_missing)
    run_test("find_day matches by date", test_find_day_matches_by_date)
    run_test("find_day returns None when absent", test_find_day_returns_none_when_absent)
    run_test("find_month matches year and month", test_find_month_matches_year_and_month)
    run_test("find_month returns None when absent", test_find_month_returns_none_when_absent)
    run_test("human formats bytes", test_human_bytes)
    run_test("human formats KiB/MiB/GiB", test_human_kib_mib_gib)
    run_test("derive picks yesterday, month, and rows", test_derive_picks_yesterday_and_month_and_rows)
    run_test("derive month-to-date excludes days from other months", test_derive_month_to_date_excludes_days_from_other_months)
    run_test("derive yesterday is None when no matching day", test_derive_yesterday_none_when_no_matching_day)
    run_test("build_email subject includes iface and yesterday totals", test_build_email_subject_includes_iface_and_yesterday_totals)
    run_test("build_email subject notes no data when yesterday missing", test_build_email_subject_no_data_when_yesterday_missing)
    run_test("build_email plain includes month-to-date", test_build_email_plain_includes_month_to_date)
    run_test("build_email html marks today row", test_build_email_html_marks_today_row)
    run_test("build_email html omits today marker when absent", test_build_email_html_omits_today_marker_when_no_today_row)
    run_test("build_email days table titled month-to-date with total row", test_build_email_days_table_titled_month_to_date_with_total_row)
    run_test("parse_flow_lines skips non-JSON and blank lines", test_parse_flow_lines_skips_non_json_and_blank_lines)
    run_test("top_talkers attributes by local side and ranks descending", test_top_talkers_attributes_by_local_side_and_ranks_descending)
    run_test("top_talkers falls back to IP when name unresolved", test_top_talkers_falls_back_to_ip_when_name_unresolved)
    run_test("top_talkers returns empty list for no flows", test_top_talkers_returns_empty_list_for_no_flows)
    run_test("local_device_labels covers all directions", test_local_device_labels_covers_all_directions)
    run_test("build_email renders ntopng devices table when present", test_build_email_renders_ntopng_devices_table_when_present)
    run_test("build_email omits ntopng table when absent", test_build_email_omits_ntopng_table_when_absent)
    run_test("build_email omits ntopng table when None", test_build_email_omits_ntopng_table_when_none)
    print(f"\n{FAILURES} failure(s)" if FAILURES else "\nAll tests passed")
    sys.exit(1 if FAILURES else 0)
