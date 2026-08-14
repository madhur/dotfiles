# vnstat Digest — ntopng Enrichment

**Date**: 2026-08-09
**Status**: Approved
**Builds on**: [2026-08-09-vnstat-digest-design.md](2026-08-09-vnstat-digest-design.md) (the base vnstat digest — already implemented and deployed as `vnstat_digest.py`)

## Purpose

vnstat only reports interface-level totals ("X bytes in/out yesterday"). It
can't say *who* used the bandwidth or *what kind* of traffic it was. ntopng,
already running on `enp5s0`, classifies every flow by local device and by
application (nDPI). This adds two tables to the existing vnstat digest — top
devices and top applications, both for the same "yesterday" window the
digest already reports — without touching vnstat's own numbers.

## Context — what's available on this box

- `ntopng@enp5s0.service` runs continuously, configured (via
  `/etc/systemd/system/ntopng@.service.d/override.conf`) to write one
  structured JSON record per completed flow to syslog, captured into a
  dedicated journald namespace `ntopng-flows`
  (`/etc/systemd/journald@ntopng-flows.conf.d`, `Storage=persistent`,
  `SystemMaxUse=20G`, `MaxRetentionSec=30day` — comfortably enough for a
  "yesterday" lookup).
- Reading that namespace requires root; passwordless sudo for `journalctl`
  in it is already configured on this box (used today by
  `/usr/local/bin/bigflows`, a "big single flows" report script — this
  design reuses its exact `journalctl` invocation pattern, not its code).
- Each flow record includes (fields used here): `IPV4_SRC_ADDR`,
  `IPV4_DST_ADDR`, `SRC_ADDR_LOCAL`, `DST_ADDR_LOCAL` (booleans), `SRC_NAME`,
  `DST_NAME` (resolved hostnames when known), `L7_PROTO_NAME` (nDPI
  application classification, e.g. `TLS`, `YouTube`, `BitTorrent`,
  `HTTP.SOAP`), `IN_BYTES`, `OUT_BYTES`.
- ntopng's live REST API (`http://localhost:3000/lua/rest/v2/...`,
  unauthenticated from localhost) was considered and **rejected** as the
  data source: it reflects only the current ntopng process's in-memory
  session and resets on every restart (confirmed: the process restarted
  today at 14:45 IST), so it cannot reliably answer "what happened
  yesterday." InfluxDB (ntopng's optional long-term store) is disabled on
  this box (`system/health/influxdb.lua` → `"status":"DISABLED"`), so the
  flow journal is the only durable historical source.
- System timezone is `Asia/Kolkata` (confirmed via `timedatectl`), so
  `journalctl --since/--until "YYYY-MM-DD HH:MM:SS"` boundaries line up
  exactly with the IST day boundaries `vnstat_digest.py` already computes
  for "yesterday" — no timezone-conversion logic needed.
- Live-checked: the flow journal has **zero records for 2026-08-08**
  (yesterday, as of this writing) — ntopng's own logging only started
  today. This is expected on a fresh box (vnstat's history is similarly
  thin) and is exactly the case the "no data" degradation path (below)
  exists for. Behavior once the journal has real history is unit-tested
  against synthetic fixtures instead.

## Data Flow

1. `fetch_flow_lines(since: str, until: str) -> list[str]` — runs
   `sudo -n journalctl --namespace=ntopng-flows -o cat --since <since> --until <until>`
   and returns stdout split into lines. (Impure; not unit-tested, same
   convention as `fetch_raw()` in the base digest.)
2. `parse_flow_lines(lines: Iterable[str]) -> list[dict]` — pure. Keeps only
   lines starting with `{` and parsing as JSON; silently skips anything
   else (matches `bigflows.fetch_records`'s tolerance of non-JSON syslog
   noise in the same namespace).
3. `top_talkers(flows: list[dict]) -> list[dict]` — pure, **no truncation**.
   Returns `[{"label": str, "bytes": int}, ...]`, sorted descending, for
   *every* distinct local device seen. For each flow, if `SRC_ADDR_LOCAL`
   add its bytes to `SRC_NAME or IPV4_SRC_ADDR`'s total; if
   `DST_ADDR_LOCAL` add to `DST_NAME or IPV4_DST_ADDR`'s total. (A
   local↔local flow contributes to both endpoints — both devices genuinely
   participated.) Bytes = a flow's full `IN_BYTES + OUT_BYTES`, attributed
   to the local device on that side regardless of which direction the bulk
   of the traffic ran.
4. `top_apps(flows: list[dict]) -> list[dict]` — pure, **no truncation**.
   Same output shape and full-list contract as `top_talkers`, keyed by
   `L7_PROTO_NAME` (falls back to `"Unknown"` if absent) — this table
   answers "what kind of traffic," not "whose."

   Truncation to `TOP_N` and the "+k more, totalling X" remainder both
   happen at render time in `build_email` (see below) — one place derives
   both `rows[:top_n]` and `rows[top_n:]` from the same full list, so they
   can never disagree. Neither aggregator takes a `top_n` argument.
5. `gather_ntopng(today: date) -> dict | None` — orchestration. Computes
   yesterday's `since`/`until` strings, calls `fetch_flow_lines`, parses,
   and returns `None` if the parsed flow list is empty (no data —
   including today's known-empty case) or if `fetch_flow_lines` raises
   `FileNotFoundError` (no `journalctl`/`sudo`) or
   `subprocess.CalledProcessError` (command failed — e.g. sudoers rule
   missing or removed). Any of those logs one `WARNING:` line to stderr and
   returns `None`; nothing else in the digest is affected. On success,
   returns `{"talkers": top_talkers(flows), "apps": top_apps(flows)}` (both
   full, untruncated lists — `TOP_N` is a rendering concern, not a
   gathering one).
6. `gather()` (existing, base digest) is extended to call `gather_ntopng()`
   and attach its result under a new `"ntopng"` key on the context dict
   passed to `build_email()`.

## Email Changes

`build_email(d)` renders two additional tables **only when
`d.get("ntopng")` is not `None`** — inserted after the existing "last N
days" table, before the footer:

- **Top devices (yesterday)** — Device | Traffic, from `talkers`.
- **Top applications (yesterday)** — Application | Traffic, from `apps`.

Each table gets a trailing note when there are more entries than fit in the
top N — "+`k` more, totalling `human(remainder)`" — computed in
`build_email` from the same full (untruncated) list `top_talkers`/
`top_apps` already returned: `shown = rows[:TOP_N]`,
`rest = rows[TOP_N:]`, note only rendered when `rest` is non-empty.

`_table()` (existing helper) gains an optional `note: str = ""` parameter
(currently `docker_digest.py` has this; `vnstat_digest.py`'s copy doesn't
yet) — appends a small `<p>` line after the table, same styling as
`docker_digest.py`'s version.

When `d.get("ntopng")` is `None` (degraded/no data), neither table nor any
placeholder text is rendered — the email looks exactly as it does today.
No visible "ntopng unavailable" notice; the stderr warning from
`gather_ntopng()` is the only trace, consistent with treating this as
optional enrichment, not a monitored dependency.

## Config

New key in `vnstat-digest.env`, alongside the existing ones:

```
# Rows to show in the top-devices / top-applications tables (ntopng flow
# journal enrichment). Same knob controls both tables.
TOP_N=5
```

Default `5` if unset (matches the value chosen for this feature). No new
env var for enabling/disabling ntopng enrichment — it self-disables
whenever the flow journal has nothing for yesterday, which already covers
"ntopng not installed" and "ntopng not running" (empty/failed query) as
well as "ntopng running but log-thin" — one degradation path handles all
three.

## Error Handling

| Condition | Behavior |
|---|---|
| `journalctl`/`sudo` binary missing | `gather_ntopng()` catches `FileNotFoundError`, logs `WARNING: ntopng enrichment skipped: ...`, returns `None`. Digest sends without the two tables. |
| `journalctl --namespace=ntopng-flows` command fails (bad sudoers, namespace doesn't exist) | Caught via `subprocess.CalledProcessError`, same as above. |
| Query succeeds but zero flows for yesterday | `gather_ntopng()` returns `None` (no exception — this is the expected/common case on a fresh box), same visible behavior as above. |
| Malformed/non-JSON lines mixed into the journal output | `parse_flow_lines` skips them silently (not an error). |
| Everything present and healthy | Two tables render as designed. |

None of these can turn a working vnstat send into a failed one — this is
purely additive.

## Testing

- `parse_flow_lines`: given a mix of valid-JSON, garbage, and blank lines,
  returns only the valid flow dicts.
- `top_talkers`: fixture with (a) a local→remote flow, (b) a remote→local
  flow, (c) a local↔local flow — asserts correct attribution and ordering,
  including the local↔local double-count.
- `top_apps`: fixture with multiple `L7_PROTO_NAME` values including one
  flow missing the field (→ `"Unknown"`) — asserts correct sums and
  ordering.
- `build_email`: one test with an `ntopng` key present (asserts both tables
  render with expected labels/values), one with `ntopng: None` (asserts
  neither table's markers appear — output identical in shape to the base
  digest's existing tests).
- `gather_ntopng()` itself: not unit-tested (subprocess/sudo I/O), same
  convention as `fetch_raw()`/`gather()` in the base digest. Verified
  manually: (1) a live run once the journal has genuine "yesterday" data,
  confirming table contents look sane against `bigflows`' own output for
  the same window; (2) today's live run, right now, exercises the
  zero-records degradation path for real (confirmed above: 0 records for
  2026-08-08) — this IS the manual verification of that path, not merely
  "reasoned about," unlike the equivalent base-digest edge case which
  couldn't be forced live.

## Explicitly Out of Scope (YAGNI)

- Percentage-of-day-total column on either table (raw bytes are enough at
  this scale; add later if it becomes hard to read).
- A visible "ntopng data unavailable" line in the email body — stderr-only,
  per the "skip silently" decision.
- Security/risk callouts from `L7_RISK_SCORE` or blacklisted addresses —
  a genuinely different feature (security monitoring vs. bandwidth
  reporting); not requested.
- Any use of ntopng's live REST API — rejected above as unsuitable for a
  "yesterday" report.
- A `TOP_N`-enable/disable toggle for ntopng enrichment specifically — the
  empty-data degradation already covers "don't want this" (remove the
  sudoers rule or stop ntopng, the section disappears on its own).
