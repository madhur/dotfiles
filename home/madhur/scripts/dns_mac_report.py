#!/usr/bin/env python3
"""dns_mac_report.py - render a live HTML report of the Mac's (192.168.1.176)
DNS queries, from dnsmasq's log-queries=extra log
(/var/log/dnsmasq-router-hairpin.log on the router host).

Companion to the linux-router repo's DNS hijack (see
config/router-hairpin.nft's `prerouting` chain): that DNAT rule forces the
Mac's port-53 traffic through this router's dnsmasq regardless of what
server it's actually addressed to; dnsmasq's `log-queries=extra` tags every
log line for a given query with a shared serial number + requestor IP,
which is what makes correlating a reply back to its query possible under
concurrent LAN traffic. See the design doc:
linux-router/docs/superpowers/specs/2026-08-16-mac-dns-hijack-dashboard-design.md

Regenerated every 5 minutes by dns-mac-report.timer, same pattern as
~/scripts/bigflows + ntopng-flow-report.timer. Stateless: re-reads and
re-renders the whole thing from the log file on every run, no cache.
"""
import re

DEFAULT_LOG_FILE = "/var/log/dnsmasq-router-hairpin.log"
DEFAULT_CLIENT_IP = "192.168.1.176"
DEFAULT_LIMIT = 200
REFRESH_SECONDS = 300

# "Aug 16 15:32:03 dnsmasq[233431]: 1 192.168.1.176/42979 query[A] example.com from 192.168.1.176"
LINE_RE = re.compile(
    r'^(?P<time>\w{3}\s+\d+ \d{2}:\d{2}:\d{2}) \S+\[\d+\]: '
    r'(?P<serial>\d+) (?P<client>[\d.]+)/\d+ (?P<rest>.*)$'
)
QUERY_RE = re.compile(r'^query\[(?P<qtype>\S+)\] (?P<domain>\S+) from')
# dnsmasq answers a query with one of several verbs, all sharing this same
# "<verb> <name> is <answer>" shape: `reply` (forwarded upstream), `cached`
# (served from dnsmasq's cache), `config` (served from a local `address=`
# rule -- e.g. the blackhole entries in dnsmasq.conf), and the literal hosts
# file path (served from /etc/hosts -- this deployment's dnsmasq.conf has no
# no-hosts/addn-hosts override, so on this router that path is `/etc/hosts`).
REPLY_RE = re.compile(r'^(?:reply|cached|config|/etc/hosts) \S+ is (?P<answer>.+)$')
# A local-lease-answered PTR (reverse-DNS) lookup logs a shape of its own:
# `DHCP <ip> is <hostname>` -- unlike REPLY_RE's verbs, the middle token
# here is the IP being looked up, not the domain that was queried, and the
# record it completes is the query[PTR] for that same IP under the same
# serial. Kept as a separate regex/case (rather than folded into REPLY_RE)
# to keep that semantic difference explicit.
DHCP_RE = re.compile(r'^DHCP \S+ is (?P<answer>.+)$')


def parse_dns_log(lines, client_ip):
    """Parse log-queries=extra lines into completed query records for
    client_ip, in log order. Each record:
      {"time": str, "qtype": str, "domain": str, "answers": [str, ...]}
    Queries with no reply line yet (still in flight, or log tailed
    mid-query) are omitted -- they show up once the reply lands on a
    later run.
    """
    # `queries` maps serial -> the CURRENT (most recent) record for that
    # serial; `order` stores direct references to every record ever
    # created, in creation order. Two separate references matter because
    # dnsmasq's serial numbers reset to 1 on every restart -- if the log
    # file spans a restart (it isn't rotated during the audit), a later
    # query can reuse an earlier query's serial. Keying `order` by serial
    # string (and re-looking-up `queries[serial]` at the end) would let
    # the later query's dict silently overwrite/merge with the earlier
    # one's in the output. Storing the dict reference itself in `order`
    # at creation time means an earlier record is untouched by later
    # reuse of its serial -- only reply lines (matched via `queries[serial]`,
    # which always resolves to the newest record) can still mutate it,
    # which is correct since replies always follow their own query line.
    queries = {}
    order = []
    for line in lines:
        m = LINE_RE.match(line)
        if not m or m.group("client") != client_ip:
            continue
        serial = m.group("serial")
        rest = m.group("rest")
        qm = QUERY_RE.match(rest)
        if qm:
            record = {
                "time": m.group("time"),
                "qtype": qm.group("qtype"),
                "domain": qm.group("domain"),
                "answers": [],
            }
            queries[serial] = record
            order.append(record)
            continue
        rm = REPLY_RE.match(rest)
        if rm and serial in queries:
            queries[serial]["answers"].append(rm.group("answer"))
            continue
        dm = DHCP_RE.match(rest)
        if dm and serial in queries:
            queries[serial]["answers"].append(dm.group("answer"))
    return [record for record in order if record["answers"]]


import argparse
import html as htmlmod
import sys
from datetime import datetime


def render_html(records, generated_at, client_ip, refresh_seconds=REFRESH_SECONDS):
    rows = []
    for r in records:
        answers = htmlmod.escape(", ".join(r["answers"]))
        rows.append(
            "<tr><td>{time}</td><td>{qtype}</td><td>{domain}</td><td>{answers}</td></tr>".format(
                time=htmlmod.escape(r["time"]),
                qtype=htmlmod.escape(r["qtype"]),
                domain=htmlmod.escape(r["domain"]),
                answers=answers,
            )
        )
    table_body = "\n".join(rows) if rows else '<tr><td colspan="4">No queries seen yet.</td></tr>'
    return """<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="refresh" content="{refresh}">
<title>Mac DNS queries</title>
<style>
body {{ font-family: sans-serif; margin: 2rem; }}
table {{ border-collapse: collapse; width: 100%; }}
th, td {{ text-align: left; padding: .35rem .6rem; border-bottom: 1px solid #ddd; }}
th {{ background: #f4f4f4; }}
.meta {{ color: #999; margin-bottom: 1rem; font-size: .85rem; }}
</style>
</head><body>
<h1>DNS queries &mdash; {client_ip}</h1>
<div class="meta">Generated {generated_at} &middot; auto-refreshes every {refresh_min} min</div>
<table>
<tr><th>Time</th><th>Type</th><th>Domain</th><th>Answer</th></tr>
{table_body}
</table>
</body></html>
""".format(
        refresh=refresh_seconds,
        client_ip=htmlmod.escape(client_ip),
        generated_at=htmlmod.escape(generated_at),
        refresh_min=refresh_seconds // 60,
        table_body=table_body,
    )


def cap_records(records, limit):
    """Return records newest-first, capped to at most `limit` rows.
    `limit <= 0` means unlimited -- matches the sibling bigflows script's
    `--limit` convention ("0 for unlimited"), not Python slicing's own
    "0 means empty" reading of `records[-0:]`. Negative limits are treated
    the same as 0 (unlimited) rather than producing a confusing slice.
    """
    capped = records[-limit:] if limit > 0 else records
    return list(reversed(capped))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log-file", default=DEFAULT_LOG_FILE)
    parser.add_argument("--client-ip", default=DEFAULT_CLIENT_IP)
    parser.add_argument("--limit", type=int, default=DEFAULT_LIMIT,
                         help="max rows, 0 for unlimited (default: %(default)s)")
    parser.add_argument("--html", required=True, help="output HTML path")
    args = parser.parse_args()

    try:
        with open(args.log_file, "r", errors="replace") as f:
            records = parse_dns_log(f, args.client_ip)
    except OSError as e:
        print(f"dns_mac_report: cannot read {args.log_file}: {e}", file=sys.stderr)
        sys.exit(1)

    records = cap_records(records, args.limit)  # newest first, capped
    generated_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    out = render_html(records, generated_at, args.client_ip)

    with open(args.html, "w") as f:
        f.write(out)
    print(f"dns_mac_report: wrote {len(records)} record(s) to {args.html}")


if __name__ == "__main__":
    main()
