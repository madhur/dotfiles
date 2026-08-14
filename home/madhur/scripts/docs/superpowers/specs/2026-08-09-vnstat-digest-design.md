# vnstat Daily Digest → Mailpit

**Date**: 2026-08-09
**Status**: Approved

## Purpose

Email a daily snapshot of network traffic on the main NIC (`enp5s0`) via the
existing homelab Mailpit pipeline, so bandwidth usage is visible without
manually running `vnstat`.

## Context

- `vnstat` (2.13) is already installed and monitoring `enp5s0`, the only
  physical NIC on this box with real traffic — everything else under `ip
  link` is a docker bridge or veth pair.
- The homelab already has a family of daily digest scripts
  (`docker_digest.py`, `firefly_digest.py`, `bookstack_digest.py`,
  `ccusage_digest.py`) that share one shape:
  - Python, run from the `python-rsha` virtualenv
    (`#!/home/madhur/.virtualenvs/python-rsha/bin/python`).
  - `from homelab import set_source` + `set_source("<name>")` so sends are
    tagged in Prometheus (`service=mailpit, source=<name>`).
  - Delivery via `homelab.clients.mailpit.push()` (stdlib `smtplib` under the
    hood, best-effort, never raises).
  - Config loaded from a sibling `<name>-digest.env` via `python-dotenv`,
    with defaults baked into the script.
  - A self-contained dark-theme inline-HTML template (small `_esc`/`_stat`/
    `_cell`/`_table` helpers duplicated per script, not shared — confirmed by
    reading `docker_digest.py`).
  - Invoked from `~/scripts/every_24_hours.sh` via `run_with_notification`,
    which itself runs off `every24hours.timer` (systemd user timer, fires
    ~20:02 IST daily).
- This digest follows that exact pattern rather than inventing a new one.

## Data Source

`vnstat -i <IFACE> --json` (no subcommand) returns, in one call:
- `traffic.total` — all-time rx/tx.
- `traffic.day[]` — one entry per day (`date`, `rx`, `tx`), including an
  in-progress entry for today if any traffic has been recorded.
- `traffic.month[]` — one entry per month.

No other vnstat subcommands (`h`, `top`, `5m`) are needed for this design.

### Derived values

- **Yesterday** = the `day[]` entry whose date equals `(now − 1 day)`. This is
  the most recent *complete* 24h period — since the digest fires at ~20:02
  IST, "today" is still ~83% through and would understate a full day. If no
  entry matches (e.g. vnstat's DB doesn't go back that far yet), render "no
  data for yesterday" instead of failing.
- **Month-to-date** = the `month[]` entry whose `(year, month)` equals the
  current month. Falls back to "no data" if absent.
- **Last N days table** = the tail of `day[]` (`DAYS_TABLE` entries, default
  7), sorted most-recent-first. If the last entry's date is today, its row is
  labeled "(so far)" to flag it's partial.

### Units

vnstat's own CLI reports in binary units (GiB/MiB/KiB), unlike the Docker CLI
(decimal). This digest's `human()` formatter matches vnstat's convention
(1024-based) so numbers in the email match what `vnstat -i enp5s0` prints on
the terminal.

## Email

**Subject**: `vnstat — <iface> — <rx> ↓ / <tx> ↑ yesterday (<DD Mon>)`
(falls back to a "no data yet" subject if yesterday has no entry).

**Body** (dark HTML, matching the sibling digests' template style):
1. Headline stat tiles: Yesterday RX, Yesterday TX, Yesterday Total,
   Month-to-date Total.
2. One table: last `DAYS_TABLE` days — Date | RX | TX | Total — most recent
   first, today's row (if present) marked "(so far)".
3. Footer: interface name, "data since `<vnstat created date>`".

Plain-text `body` fallback for the multipart alternative: one line summarizing
yesterday's total and month-to-date total.

**Always sends** — this is purely informational (no anomaly/threshold logic),
so there's no `SEND_WHEN_EMPTY`-style gate like the Docker digest has.

## Config — `vnstat-digest.env`

```
MAIL_FROM=vnstat-digest@madhur.co.in
MAIL_TO=ahuja.madhur@gmail.com
VNSTAT_IFACE=enp5s0
DAYS_TABLE=7
```

All keys optional; defaults above are also baked into the script.

## Error Handling

- `vnstat` binary not found (`FileNotFoundError`) → stderr message, exit 1.
- `vnstat` process fails (`CalledProcessError`, e.g. bad interface name) →
  stderr message including vnstat's stderr, exit 1.
- Interface not present in the JSON `interfaces[]` array (e.g. `VNSTAT_IFACE`
  misconfigured, or vnstat isn't tracking it) → explicit stderr message
  naming the interface, exit 1.
- Any of the above surfaces through `run_with_notification`'s existing
  failure-notification path in `every_24_hours.sh` — no new alerting needed.
- Empty `day[]`/`month[]` (fresh vnstat DB) is NOT an error — render "no data"
  in the relevant section and still send.

## Wiring

One line added to `~/scripts/every_24_hours.sh`, grouped with the other
"→ Mailpit" / "monitoring" digest lines (near `docker_digest.py`):

```bash
run_with_notification "/home/madhur/scripts/vnstat_digest.py" "vnstat Daily Digest → Mailpit" "monitoring"
```

## Explicitly Out of Scope (YAGNI)

- Hourly peak/busiest-window table.
- Monthly data cap / quota tracker with a progress bar.
- `estimated`-usage-for-month projection (vnstat's CLI computes this
  client-side; not present in the JSON output, and not needed for this
  design).
- Multi-interface support — hardcoded to one `VNSTAT_IFACE`, matching how
  every other digest here targets one thing (one docker root, one Firefly
  instance, etc.).

## Testing

- Run `vnstat_digest.py` manually and confirm it exits 0 and a message
  appears in Mailpit (`http://localhost:8025` or wherever this Mailpit
  instance is reached) with sane numbers matching `vnstat -i enp5s0`'s own
  terminal output.
- Verify behavior when `VNSTAT_IFACE` is set to a nonexistent interface name
  (should exit 1 with a clear message, not send a mail, not crash).
- Verify the "no data for yesterday" fallback path is at least reasoned
  about, even though it can't be easily forced on this box (vnstat already
  has 2 days of history) — code review by inspection is sufficient here.
