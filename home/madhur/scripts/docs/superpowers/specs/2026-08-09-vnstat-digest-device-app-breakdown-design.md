# vnstat Digest — Per-Device Application Breakdown

**Date**: 2026-08-09
**Status**: Approved
**Builds on**:
[2026-08-09-vnstat-digest-design.md](2026-08-09-vnstat-digest-design.md) (base digest)
[2026-08-09-vnstat-digest-ntopng-enrichment-design.md](2026-08-09-vnstat-digest-ntopng-enrichment-design.md) (top devices / top apps tables — already implemented and deployed)

## Purpose

The flat "Top applications" table (deployed under the enrichment spec above)
answers "what kind of traffic ran yesterday" but not "which device drove
it." Replace it with a per-device breakdown: for each top device, its own
top applications.

## Data — no new source

Every flow record already carries both the local-device attribution and the
app classification (`L7_PROTO_NAME`) used by `top_talkers`/`top_apps`
respectively. This is a re-slicing of data already fetched by
`gather_ntopng()`, not a new query.

## Function Changes

- **`local_device_labels(f: dict) -> list[str]`** — new small pure helper,
  factored out of `top_talkers`'s existing per-flow logic: returns the
  local-device label(s) a flow attributes to — `[]` if neither side is
  local, one label for a local↔remote flow, two for local↔local (same
  device resolution rule as before: `SRC_NAME`/`DST_NAME`, falling back to
  the corresponding IP).
- **`top_talkers(flows)`** — refactored to iterate `local_device_labels(f)`
  instead of duplicating the src/dst branches inline. Behavior is
  unchanged (covered by the existing, unmodified unit tests — this is a
  safe internal refactor, not a behavior change).
- **`device_app_breakdown(flows: list[dict], device_label: str) -> list[dict]`**
  — new pure function. Filters `flows` to those where `device_label` is a
  local endpoint (`device_label in local_device_labels(f)`), then
  delegates to the **existing** `top_apps()` on that subset. Same
  full/untruncated, sorted-descending contract as `top_talkers`/`top_apps`.
  `top_apps()` itself is unchanged and stays in use — it is not deleted,
  just repurposed as the aggregator this new function reuses instead of
  duplicating.
- **`gather_ntopng(today)`** — now computes:
  ```python
  talkers = top_talkers(flows)
  by_device = {t["label"]: device_app_breakdown(flows, t["label"]) for t in talkers}
  return {"talkers": talkers, "by_device": by_device}
  ```
  The top-level `"apps"` key (flat, cross-device totals) is **removed** —
  replaced entirely by `"by_device"`, per the "replace, don't add a third
  table" decision.

## Email Changes

`_ntopng_tables(ntopng, top_n, apps_per_device)` (signature grows one
parameter):

1. **"Top devices (yesterday)"** — unchanged from the enrichment spec:
   `ntopng["talkers"][:top_n]`, same note convention for the remainder.
2. **"Top applications by device (yesterday)"** — replaces the old flat
   apps table. For each device in `ntopng["talkers"][:top_n]` (same top-N
   device set and order as table 1), render:
   - A heading line: `<device label> — <human(device total bytes)>`.
   - A compact 2-column table of `ntopng["by_device"][label][:apps_per_device]`
     (Application | Traffic).
   - A per-device note — `"+k more, totalling X"` — when that device has
     more apps than `apps_per_device` shows, using the same note styling as
     the existing tables (smaller, indented under that device's block since
     it's per-device, not per-table).

   A device with zero recorded apps (shouldn't happen in practice — every
   flow that puts a device in `talkers` also has some `L7_PROTO_NAME`, even
   if `"Unknown"` — but `device_app_breakdown` handles it safely by
   returning `[]`) renders no app rows and no note.

When `ntopng` is `None` (unchanged degradation path from the enrichment
spec), neither table renders — no change to that behavior.

## Config

New key in `vnstat-digest.env`:

```
# Apps shown per device in the "Top applications by device" breakdown.
APPS_PER_DEVICE=3
```

Default `3` (per approved design). `TOP_N` continues to cap the device
count (unchanged, still 5 by default) — it is now also, indirectly, the cap
on how many devices' app-breakdowns are computed and shown, since
`by_device` is built from all of `talkers` but only the top `top_n` are
rendered.

## Testing

- `local_device_labels`: local→remote (1 label), remote→local (1 label),
  local↔local (2 labels), neither side local (`[]`).
- `top_talkers`: existing tests unchanged and must still pass — this is the
  regression check that the refactor didn't alter behavior.
- `device_app_breakdown`: a device with more apps than `apps_per_device`
  would show (verifies full/untruncated return — the cap is a render-time
  concern per Task 2's existing convention, not this function's); a device
  with no matching flows → `[]`; confirms it reuses `top_apps`'s
  "Unknown" bucketing for a flow missing `L7_PROTO_NAME`.
- `build_email`: nested section renders per-device headings and app rows
  when `ntopng["by_device"]` is present; per-device "+k more" note appears
  only for a device that exceeds `apps_per_device`; a device within the cap
  shows no note; `ntopng: None` still renders neither table (unchanged
  existing test, kept as regression coverage).
- The old flat "Top applications" table's tests (from the enrichment spec)
  are removed/replaced — that table no longer exists.

## Explicitly Out of Scope (YAGNI)

- Normalizing device-label case (`Mac` vs `mac` seen in the earlier sample
  send) — a real observation worth revisiting, but a separate concern from
  this layout change; not requested here.
- A device × app matrix or any other layout — the two alternatives
  presented were declined in favor of the nested breakdown.
- Independent truncation of `by_device` computation from `top_n` (e.g.
  computing breakdowns for more devices than are shown) — no use case for
  it; `by_device` is built from every entry in `talkers`, but only the
  rendered top `top_n` matters in practice.
