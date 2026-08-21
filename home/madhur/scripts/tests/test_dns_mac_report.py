#!/usr/bin/env python3
"""Unit tests for dns_mac_report.py.

Plain assert-based tests, PASS/FAIL runner -- same convention as
tests/test_vnstat_digest.py. Run directly:
python3 ~/scripts/tests/test_dns_mac_report.py

Fixture lines below were captured live on 2026-08-16: SIMPLE_QUERY_LINES
from a throwaway dnsmasq instance (`dnsmasq -C /dev/null --log-queries=extra
--log-facility=- --port=15353 ...` + `dig example.com` / `dig example.org
AAAA`), CNAME_CHAIN_LINES from the real production log
(/var/log/dnsmasq-router-hairpin.log) -- so they match dnsmasq 2.93's
actual line format exactly, not a guessed one.

CACHED_ANSWER_LINES / CONFIG_BLACKHOLE_LINES / ETC_HOSTS_ANSWER_LINES were
captured the same way as SIMPLE_QUERY_LINES, against a throwaway instance
(`dnsmasq --conf-file=/dev/null -k -d --log-queries=extra --log-facility=-
--port=15354 --no-resolv --no-hosts --addn-hosts=<tmpfile>
--address=/blocked.example/0.0.0.0` + repeated `dig`), to get dnsmasq 2.93's
real `cached`/`config`/hosts-file-path verb formats exactly. DHCP_PTR_LINES
are real lines lifted verbatim from the production log
(/var/log/dnsmasq-router-hairpin.log, 2026-08-16) -- an actual local-lease
PTR answer for the Mac's own reverse lookup.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import dns_mac_report as dmr

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


SIMPLE_QUERY_LINES = [
    "Aug 16 15:32:03 dnsmasq[233431]: 1 192.168.1.176/42979 query[A] example.com from 192.168.1.176",
    "Aug 16 15:32:03 dnsmasq[233431]: 1 192.168.1.176/42979 forwarded example.com to 192.168.1.1",
    "Aug 16 15:32:03 dnsmasq[233431]: 1 192.168.1.176/42979 reply example.com is 104.20.23.154",
    "Aug 16 15:32:03 dnsmasq[233431]: 1 192.168.1.176/42979 reply example.com is 172.66.147.243",
    "Aug 16 15:32:03 dnsmasq[233431]: 2 192.168.1.176/41860 query[AAAA] example.org from 192.168.1.176",
    "Aug 16 15:32:03 dnsmasq[233431]: 2 192.168.1.176/41860 forwarded example.org to 192.168.1.1",
    "Aug 16 15:32:03 dnsmasq[233431]: 2 192.168.1.176/41860 reply example.org is 2606:4700:10::6814:1a88",
    "Aug 16 15:32:03 dnsmasq[233431]: 2 192.168.1.176/41860 reply example.org is 2606:4700:10::ac42:9ded",
]

CNAME_CHAIN_LINES = [
    "Aug 16 15:32:19 dnsmasq[1011]: 3 192.168.1.176/50001 query[A] m.media-amazon.com from 192.168.1.176",
    "Aug 16 15:32:19 dnsmasq[1011]: 3 192.168.1.176/50001 forwarded m.media-amazon.com to 192.168.1.1",
    "Aug 16 15:32:19 dnsmasq[1011]: 3 192.168.1.176/50001 reply m.media-amazon.com is <CNAME>",
    "Aug 16 15:32:19 dnsmasq[1011]: 3 192.168.1.176/50001 reply tp.c47710ee9-frontier.media-amazon.com is <CNAME>",
    "Aug 16 15:32:19 dnsmasq[1011]: 3 192.168.1.176/50001 reply media.amazon.map.fastly.net is 151.101.157.16",
]

OTHER_CLIENT_LINES = [
    "Aug 16 15:32:20 dnsmasq[1011]: 4 192.168.1.50/9999 query[A] netflix.com from 192.168.1.50",
    "Aug 16 15:32:20 dnsmasq[1011]: 4 192.168.1.50/9999 reply netflix.com is 3.3.3.3",
]

INCOMPLETE_QUERY_LINES = [
    "Aug 16 15:32:21 dnsmasq[1011]: 5 192.168.1.176/8888 query[A] still-resolving.example from 192.168.1.176",
]

# dnsmasq's serial numbers reset to 1 after every restart -- simulates the
# log file spanning a restart, where an earlier and a later query end up
# sharing the same serial "1".
SERIAL_REUSE_ACROSS_RESTART_LINES = [
    "Aug 16 15:30:00 dnsmasq[1011]: 1 192.168.1.176/1111 query[A] before-restart.example from 192.168.1.176",
    "Aug 16 15:30:00 dnsmasq[1011]: 1 192.168.1.176/1111 reply before-restart.example is 10.0.0.1",
    "Aug 16 15:31:00 dnsmasq[1011]: started, version 2.93 cachesize 150",
    "Aug 16 15:31:05 dnsmasq[1011]: 1 192.168.1.176/2222 query[A] after-restart.example from 192.168.1.176",
    "Aug 16 15:31:05 dnsmasq[1011]: 1 192.168.1.176/2222 reply after-restart.example is 10.0.0.2",
]

CACHED_ANSWER_LINES = [
    "Aug 16 17:05:00 dnsmasq[128290]: 10 192.168.1.176/50001 query[A] cached.example from 192.168.1.176",
    "Aug 16 17:05:00 dnsmasq[128290]: 10 192.168.1.176/50001 cached cached.example is 151.101.1.1",
]

# Same shape dnsmasq.conf's `address=/storage.googleapis.com/0.0.0.0`
# blackhole entry produces for a real blocked domain (verified against a
# throwaway instance run with an equivalent --address= rule).
CONFIG_BLACKHOLE_LINES = [
    "Aug 16 17:05:01 dnsmasq[128290]: 11 192.168.1.176/50002 query[A] storage.googleapis.com from 192.168.1.176",
    "Aug 16 17:05:01 dnsmasq[128290]: 11 192.168.1.176/50002 config storage.googleapis.com is 0.0.0.0",
]

# /etc/hosts-sourced answers log their verb as the hosts file path itself.
# This deployment's dnsmasq.conf has no no-hosts/addn-hosts override, so on
# the real router that path is the default /etc/hosts.
ETC_HOSTS_ANSWER_LINES = [
    "Aug 16 17:05:02 dnsmasq[128290]: 12 192.168.1.176/50003 query[A] hostsentry.example from 192.168.1.176",
    "Aug 16 17:05:02 dnsmasq[128290]: 12 192.168.1.176/50003 /etc/hosts hostsentry.example is 10.10.10.10",
]

# Real lines lifted verbatim from the production log
# (/var/log/dnsmasq-router-hairpin.log, 2026-08-16): a local-lease-answered
# PTR (reverse-DNS) lookup for the Mac's own IP logs as `DHCP <ip> is
# <hostname>`, a different line shape from reply/cached/config, sharing the
# preceding query[PTR] line's serial.
DHCP_PTR_LINES = [
    "Aug 16 16:41:52 dnsmasq[41742]: 243 192.168.1.176/62896 query[PTR] 176.1.168.192.in-addr.arpa from 192.168.1.176",
    "Aug 16 16:41:52 dnsmasq[41742]: 243 192.168.1.176/62896 DHCP 192.168.1.176 is mac",
]


def test_simple_query_two_answers():
    records = dmr.parse_dns_log(SIMPLE_QUERY_LINES, "192.168.1.176")
    assert len(records) == 2, f"expected 2 records, got {len(records)}"
    assert records[0]["domain"] == "example.com"
    assert records[0]["qtype"] == "A"
    assert records[0]["answers"] == ["104.20.23.154", "172.66.147.243"]
    assert records[1]["domain"] == "example.org"
    assert records[1]["qtype"] == "AAAA"


def test_cname_chain_collects_all_hops():
    records = dmr.parse_dns_log(CNAME_CHAIN_LINES, "192.168.1.176")
    assert len(records) == 1
    assert records[0]["domain"] == "m.media-amazon.com"
    assert records[0]["answers"] == ["<CNAME>", "<CNAME>", "151.101.157.16"]


def test_other_clients_filtered_out():
    records = dmr.parse_dns_log(OTHER_CLIENT_LINES, "192.168.1.176")
    assert records == []


def test_incomplete_query_omitted():
    records = dmr.parse_dns_log(INCOMPLETE_QUERY_LINES, "192.168.1.176")
    assert records == [], "a query with no reply yet must not appear"


def test_mixed_clients_only_target_returned():
    lines = SIMPLE_QUERY_LINES + OTHER_CLIENT_LINES + CNAME_CHAIN_LINES
    records = dmr.parse_dns_log(lines, "192.168.1.176")
    assert len(records) == 3
    assert all(r["domain"] != "netflix.com" for r in records)


def test_serial_reuse_across_restart_keeps_both_queries():
    records = dmr.parse_dns_log(SERIAL_REUSE_ACROSS_RESTART_LINES, "192.168.1.176")
    assert len(records) == 2, f"expected 2 records (one per side of the restart), got {len(records)}"
    assert records[0]["domain"] == "before-restart.example"
    assert records[0]["answers"] == ["10.0.0.1"]
    assert records[1]["domain"] == "after-restart.example"
    assert records[1]["answers"] == ["10.0.0.2"]


def test_render_html_includes_row_and_refresh_meta():
    records = [{"time": "Aug 16 15:32:03", "qtype": "A", "domain": "example.com", "answers": ["1.2.3.4"]}]
    out = dmr.render_html(records, "2026-08-16 15:40:00", "192.168.1.176")
    assert "example.com" in out
    assert "1.2.3.4" in out
    assert 'content="300"' in out
    assert "192.168.1.176" in out


def test_render_html_empty_state():
    out = dmr.render_html([], "2026-08-16 15:40:00", "192.168.1.176")
    assert "No queries seen yet" in out


def test_cached_verb_recognized():
    records = dmr.parse_dns_log(CACHED_ANSWER_LINES, "192.168.1.176")
    assert len(records) == 1
    assert records[0]["domain"] == "cached.example"
    assert records[0]["answers"] == ["151.101.1.1"]


def test_config_verb_recognized():
    records = dmr.parse_dns_log(CONFIG_BLACKHOLE_LINES, "192.168.1.176")
    assert len(records) == 1
    assert records[0]["domain"] == "storage.googleapis.com"
    assert records[0]["answers"] == ["0.0.0.0"]


def test_etc_hosts_verb_recognized():
    records = dmr.parse_dns_log(ETC_HOSTS_ANSWER_LINES, "192.168.1.176")
    assert len(records) == 1
    assert records[0]["domain"] == "hostsentry.example"
    assert records[0]["answers"] == ["10.10.10.10"]


def test_dhcp_ptr_answer_recognized():
    records = dmr.parse_dns_log(DHCP_PTR_LINES, "192.168.1.176")
    assert len(records) == 1
    assert records[0]["qtype"] == "PTR"
    assert records[0]["domain"] == "176.1.168.192.in-addr.arpa"
    assert records[0]["answers"] == ["mac"]


def test_cap_records_limit_zero_is_unlimited():
    # bigflows' --limit convention: "0 for unlimited" -- NOT Python
    # slicing's own "records[-0:] is everything" vs the empty list the old
    # (buggy) inline expression produced.
    records = dmr.parse_dns_log(SIMPLE_QUERY_LINES, "192.168.1.176")
    result = dmr.cap_records(records, 0)
    assert len(result) == 2, f"limit=0 must return all records, got {len(result)}"
    assert result[0]["domain"] == "example.org", "newest record should be first"
    assert result[1]["domain"] == "example.com"


def test_cap_records_limit_one():
    records = dmr.parse_dns_log(SIMPLE_QUERY_LINES, "192.168.1.176")
    result = dmr.cap_records(records, 1)
    assert len(result) == 1, f"limit=1 must return 1 record, got {len(result)}"
    assert result[0]["domain"] == "example.org", "newest record should be example.org"


def test_cap_records_negative_limit_is_unlimited():
    records = dmr.parse_dns_log(SIMPLE_QUERY_LINES, "192.168.1.176")
    result = dmr.cap_records(records, -1)
    assert len(result) == 2, f"negative limit must be treated as unlimited, got {len(result)}"
    assert result[0]["domain"] == "example.org", "newest record should be first"


if __name__ == "__main__":
    run_test("simple_query_two_answers", test_simple_query_two_answers)
    run_test("cname_chain_collects_all_hops", test_cname_chain_collects_all_hops)
    run_test("other_clients_filtered_out", test_other_clients_filtered_out)
    run_test("incomplete_query_omitted", test_incomplete_query_omitted)
    run_test("mixed_clients_only_target_returned", test_mixed_clients_only_target_returned)
    run_test("serial_reuse_across_restart_keeps_both_queries", test_serial_reuse_across_restart_keeps_both_queries)
    run_test("render_html_includes_row_and_refresh_meta", test_render_html_includes_row_and_refresh_meta)
    run_test("render_html_empty_state", test_render_html_empty_state)
    run_test("cached_verb_recognized", test_cached_verb_recognized)
    run_test("config_verb_recognized", test_config_verb_recognized)
    run_test("etc_hosts_verb_recognized", test_etc_hosts_verb_recognized)
    run_test("dhcp_ptr_answer_recognized", test_dhcp_ptr_answer_recognized)
    run_test("cap_records_limit_zero_is_unlimited", test_cap_records_limit_zero_is_unlimited)
    run_test("cap_records_limit_one", test_cap_records_limit_one)
    run_test("cap_records_negative_limit_is_unlimited", test_cap_records_negative_limit_is_unlimited)
    print(f"\n{FAILURES} failure(s)")
    sys.exit(1 if FAILURES else 0)
