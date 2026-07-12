# Idle-shutdown visibility & extend — design

## Problem

`idle-shutdown.timer` (systemd --user, kept alive via `loginctl` linger) shuts the
machine down after 60 minutes of idle. Remaining time is visible in the wibar
(AwesomeWM) and in zellij, but only while logged in locally. When accessing
homelab services (`~/docker`) remotely with the machine unattended, there's no
visibility into time remaining and no way to extend the timer. OliveTin already
has Enable/Disable/Shutdown actions but nothing that shows live remaining time
or lets you push the deadline back.

Constraint from the user: the machine will typically be in **text-mode only**
(no X server) when they want to extend remotely — so any "extend" mechanism
must not depend on a GUI/X11 session.

## Design

### 1. Extend via simulated keypress — `idle-extend.sh` (new)

Idle detection's text-mode path (`idle-lib.sh`, Priority 2) infers idleness from
the access time (atime) of each logged-in tty, from `who | grep "^${USER} "`.
`idle-extend.sh` reuses that exact same tty discovery loop and, for each tty
found, runs:

```bash
doas python3 -c "
import fcntl, termios, os
fd = os.open('/dev/$tty_dev', os.O_RDWR | os.O_NOCTTY)
fcntl.ioctl(fd, termios.TIOCSTI, b'\x00')
os.close(fd)
"
```

`TIOCSTI` injects a byte into the tty's input queue as if it were typed —  a
real simulated keypress, not a fake override flag. A null byte (`\x00`) is
invisible to the shell (no visible character, no readline side effect) but is
enough to update the tty's atime, which `get_idle_ms()` already reads. No new
packages or daemons are required: `doas` is already passwordless for the
`wheel` group (which `madhur` is in — confirmed via `doas python3 ...` testing,
including verifying it actually bumps `/dev/tty1`'s atime), and the injection
uses only Python stdlib (`fcntl`, `termios`, `os`).

Logs one line to `~/logs/idle-shutdown.log` (`Simulated keypress to extend idle
timer`) for auditability.

A new OliveTin action, **"Extend Idle Shutdown"**, runs this script over the
existing SSH connection pattern used by all other OliveTin actions. Added next
to Enable/Disable in the Quick Actions and Power dashboards.

Explicitly out of scope: no GUI/X11 path (`xdotool` etc.) — not needed given
the text-mode-only constraint, and not worth the added complexity.

### 2. Live remaining time on demand — upgrade "Check Idle Shutdown Status"

The existing OliveTin action currently reports only enabled/disabled. Its shell
command is swapped to call the existing `idle-remaining-plain.sh` (already
computes remaining minutes, already used by the zellij/zjstatus integration),
so tapping it from a phone shows live remaining minutes, not just on/off. No
new script needed.

### 3. One-time pre-shutdown alert — `idle-shutdown.sh`

On each minute-tick, once remaining time first drops to ≤5 minutes in a given
idle streak, push a notification via the existing `homelab-ntfy` bridge:

```bash
homelab-ntfy --topic bootup --priority urgent \
  --click https://olivetin.desktop.madhur.co.in \
  --title "Shutting down in ~5 min (idle)" \
  "Idle for $IDLE_MINUTES min. Tap to open OliveTin and extend."
```

Tapping the notification opens OliveTin directly; the existing
Authelia/session handles auth as normal (no auth bypass, no webhook token —
this was an explicit choice over a one-tap in-notification extend button).

A state file (`~/.local/state/idle-shutdown-alerted`) dedupes so the alert
fires exactly once per idle streak:
- Remaining ≤ 5 and state file absent → send alert, touch the file.
- Remaining > 5 → remove the state file if present (resets for the next
  streak — covers both real activity and a successful extend).

### Explicitly out of scope

- The `DISPLAY=:0` hardcoding bug in `idle-shutdown.service`/`idle-lib.sh`
  (discovered during investigation — the real X session runs on `:1`, so X11
  idle detection currently silently falls back to tty-based detection even
  when a GUI session is active). User asked not to touch this now.
- A persistent dashboard widget (glance/homepage). Superseded by #2 (on-demand
  check) + #3 (proactive alert) — revisit only if that combination turns out
  to be insufficient in practice.
- Any one-tap "Extend" button embedded directly in the ntfy notification
  (would require an Authelia bypass / token-authenticated webhook).

## Files touched

- `~/scripts/idle-extend.sh` — new
- `~/scripts/idle-shutdown.sh` — add alert block (state file check + push)
- `~/docker/olivetin/OliveTin-config/config.yaml` — new "Extend Idle Shutdown"
  action; "Check Idle Shutdown Status" action's shell command swapped

## Testing

- Temporarily lower `THRESHOLD_MS` in `idle-shutdown.sh` for a dry run;
  confirm the alert fires exactly once as remaining crosses ≤5, and that the
  state file clears once remaining goes back above 5.
- Run `idle-extend.sh` while idle and confirm (via `idle-shutdown.log` and
  `idle-remaining-plain.sh` output) that idle time resets to ~0.
- Trigger both updated/new OliveTin actions over SSH from the OliveTin UI and
  confirm expected output.
- Confirm normal (non-extended, non-alerted) shutdown behavior is unaffected.
