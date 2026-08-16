# README star history — self-hosted chart

## Problem

`README.md` embeds a live badge from `api.star-history.com`, which scrapes
GitHub's star data unauthenticated:

```md
[![Star History Chart](https://api.star-history.com/svg?repos=madhur/dotfiles&type=date&legend=top-left)](https://www.star-history.com/#madhur/dotfiles&type=date&legend=top-left)
```

GitHub has restricted access to that third-party service, so viewers of the
README can no longer see the chart (broken image). The fix: fetch star data
ourselves using an authenticated `gh` call (already logged in, higher rate
limit, not subject to the third-party restriction), render a static chart,
and commit it into the repo so it's just a normal embedded image — no runtime
dependency on an external chart service at all.

## Design

### 1. `star_history_digest.py` (new) — fetch + render

New script at `~/scripts/star_history_digest.py`, run with the `python-rsha`
venv (`matplotlib`, `pandas`, `requests` already installed there — same venv
every other `*_digest.py` weekly script uses).

**Fetch:** shells out to `gh api` (already-authenticated `gh` CLI, avoids the
unauthenticated rate limit that's breaking the current badge):

```bash
gh api --paginate 'repos/madhur/dotfiles/stargazers' \
  -H 'Accept: application/vnd.github.star+json'
```

This returns one JSON object per stargazer including `starred_at`. Collect
all `starred_at` timestamps across pages.

**Render:** sort timestamps ascending, build a cumulative-count step series
(`stars_so_far` after each new star), plot with matplotlib:
- Single line, GitHub-blue (`#0969da`), step-style
- Light background (matches the "plain PNG" choice — no dark-mode variant)
- X-axis: date; Y-axis: "Stars"; title: `madhur/dotfiles star history`
- Save to `screenshots/star-history.png` in the dotfiles repo working tree,
  overwriting the previous week's file

**Scope:** `madhur/dotfiles` only — matches today's badge exactly, not a
multi-repo chart.

**Failure handling:** if the `gh api` call fails (non-zero exit, network
error, empty/malformed response) or returns zero stargazers, the script exits
non-zero **without writing/overwriting `screenshots/star-history.png`**. A
failed run silently keeps last week's chart rather than blanking the README.

### 2. `every_week.sh` — wire into existing weekly automation

One new line added right before the existing `gulp backup-and-push` step,
using the same `run_with_notification` wrapper every other weekly job uses
(so success/failure reports via ntfy exactly like the rest of the file):

```bash
run_with_notification "/home/madhur/.virtualenvs/python-rsha/bin/python /home/madhur/scripts/star_history_digest.py" "Star History Chart" "weekly"
run_with_notification "cd /home/madhur/gitpersonal/dotfiles && node_modules/gulp-cli/bin/gulp.js backup-and-push" "Dotfiles update and push" "weekly" "false" "true" "false"
```

No new git logic is needed: `gulp backup-and-push` already stages, commits,
and pushes the whole dotfiles working tree every week, so the new/changed PNG
just rides along with everything else it already commits.

### 3. `README.md` — swap badge for local image

Replace the `## Star History` section's external badge with a plain `<img>`
pointing at the committed file, consistent with how the other README images
(`keybindings.png`, `rofi.png`, etc.) are already referenced:

```md
## Star History

<img alt="Star History Chart" src="https://raw.githubusercontent.com/madhur/dotfiles/master/screenshots/star-history.png" />
```

The link to `star-history.com`'s interactive view is dropped along with the
badge — it depended on the same restricted access.

### Explicitly out of scope

- Multi-repo chart (only `madhur/dotfiles`).
- Light/dark theme pair — single light-background PNG only, per user choice.
- A dedicated git commit/push step for just this file — it piggybacks on the
  existing weekly `gulp backup-and-push`, not a standalone commit.

## Files touched

- `~/scripts/star_history_digest.py` — new
- `~/scripts/every_week.sh` — one new `run_with_notification` line
- `README.md` (dotfiles repo) — `## Star History` section updated
- `screenshots/star-history.png` (dotfiles repo) — new, generated/overwritten
  weekly, not hand-edited

## Testing

- Run `~/.virtualenvs/python-rsha/bin/python ~/scripts/star_history_digest.py`
  manually; confirm `screenshots/star-history.png` is written and looks like
  a reasonable step chart.
- Spot-check the rendered final cumulative count against
  `gh api repos/madhur/dotfiles --jq .stargazers_count`.
- Temporarily break the `gh api` call (e.g. bad repo name) and confirm the
  script exits non-zero and leaves the existing PNG untouched.
- Run `every_week.sh` end-to-end once and confirm the PNG shows up
  committed+pushed by the `gulp backup-and-push` step, and that ntfy reports
  both steps' status.
- View `README.md` on GitHub and confirm the image renders.
