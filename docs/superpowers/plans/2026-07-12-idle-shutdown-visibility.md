# Idle-shutdown visibility & extend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give remote-only (text-mode, no GUI) visibility into the idle-shutdown countdown and a way to push it back, using the existing OliveTin/ntfy stack.

**Architecture:** Three independent additions wired into the existing `idle-shutdown.timer` (fires every minute) and OliveTin action runner: (1) a new script that resets the idle clock via a simulated console keypress (TIOCSTI), triggered as an OliveTin action; (2) a small sourceable library that fires a one-time low-battery-style ntfy alert, unit-tested with a stubbed notifier; (3) an OliveTin action that reports live remaining minutes on demand.

**Tech Stack:** Bash, Python 3 stdlib (`fcntl`, `termios`, `os`) for the TIOCSTI injection, `doas` (passwordless for `wheel`), the existing `homelab-ntfy` CLI, OliveTin YAML config.

## Global Constraints

- No GUI/X11 dependency anywhere in the extend path — the target machine will be text-mode only (confirmed: `doas python3` TIOCSTI injection into `/dev/tty1` works and verifiably bumps its atime, independent of any display server).
- No new system packages or daemons (no `ydotool`, no uinput setup) — `doas` + Python stdlib only.
- `doas` is already passwordless for the `wheel` group (`madhur` is a member) — do not add sudoers/doas rules.
- ntfy topic for the pre-shutdown alert must be `bootup` (existing convention), sent via the existing `/home/madhur/.virtualenvs/python-rsha/bin/homelab-ntfy` CLI, not raw `curl`.
- The alert links to `https://olivetin.desktop.madhur.co.in` via `--click` — no auth-bypass webhook, no one-tap extend button in the notification itself.
- Alert fires exactly once per idle streak, at remaining ≤ 5 minutes.
- Follow existing script conventions in `~/scripts/`: log to `~/logs/idle-shutdown.log`, `#!/bin/bash` shebang, no `set -e` (existing scripts in this dir don't use it).

---

## File Structure

- `~/scripts/idle-extend.sh` — new. Simulates a keypress on every logged-in tty to reset the idle clock.
- `~/scripts/idle-alert-lib.sh` — new. Sourceable library exposing `maybe_send_idle_alert()`, the one-time-per-streak ntfy alert with state-file dedup.
- `~/scripts/tests/test-idle-alert-lib.sh` — new. Unit tests for `maybe_send_idle_alert()` using a stubbed notifier (no real network calls).
- `~/scripts/idle-shutdown.sh` — modified. Computes `REMAINING_MINUTES` and calls `maybe_send_idle_alert`.
- `~/docker/olivetin/OliveTin-config/config.yaml` — modified. New "Extend Idle Shutdown" action; "Check Idle Shutdown Status" action's `shell:` command swapped to report live remaining minutes.

---

### Task 1: `idle-extend.sh` — simulate a keypress to reset idle time

**Files:**
- Create: `/home/madhur/scripts/idle-extend.sh`

**Interfaces:**
- Produces: an executable script with no arguments, exit 0 on success (at least one tty found and injected into), exit 1 if no logged-in ttys were found. Appends one line to `~/logs/idle-shutdown.log` on success.

- [ ] **Step 1: Write the script**

```bash
#!/bin/bash
#
# Idle Extend Script
# Simulates a keypress on every logged-in tty to reset the idle clock,
# so the machine behaves exactly as if you'd typed something — no
# override flag, no snooze file. Text-mode only (no X11/GUI dependency):
# uses TIOCSTI to inject a byte into the tty's input queue, which is
# enough to bump the tty's atime (what idle-lib.sh's text-mode path
# reads to compute idleness).
#
# A NUL byte (\x00) is used because it's invisible to the shell — no
# visible character, no readline side effect — but it still counts as
# a real keypress at the kernel level.

LOG_FILE="$HOME/logs/idle-shutdown.log"
mkdir -p "$HOME/logs"

TTYS=$(who | grep "^${USER} " | awk '{print $2}')

if [ -z "$TTYS" ]; then
    echo "$(date): idle-extend: no logged-in ttys found, nothing to do" >> "$LOG_FILE"
    exit 1
fi

while read -r tty_dev; do
    [ -n "$tty_dev" ] && [ -e "/dev/$tty_dev" ] || continue
    doas python3 -c '
import fcntl, termios, os, sys
fd = os.open(sys.argv[1], os.O_RDWR | os.O_NOCTTY)
fcntl.ioctl(fd, termios.TIOCSTI, b"\x00")
os.close(fd)
' "/dev/$tty_dev"
done <<< "$TTYS"

echo "$(date): Simulated keypress to extend idle timer (ttys: $(echo "$TTYS" | tr '\n' ' '))" >> "$LOG_FILE"
exit 0
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x ~/scripts/idle-extend.sh`

- [ ] **Step 3: Verify baseline idle time**

Run: `stat -c %X /dev/tty1 && source ~/scripts/idle-lib.sh && get_idle_ms && echo "idle_ms=$IDLE_MS"`
Expected: prints an atime epoch and an `idle_ms` value reflecting genuine idle time (non-zero if you haven't touched a tty recently).

- [ ] **Step 4: Run the script and verify it resets idle time**

Run: `~/scripts/idle-extend.sh; echo "exit=$?"`
Expected: `exit=0`, no errors printed.

Run: `stat -c %X /dev/tty1`
Expected: atime is now the current time (larger than the Step 3 baseline).

Run: `source ~/scripts/idle-lib.sh && get_idle_ms && echo "idle_ms=$IDLE_MS"`
Expected: `idle_ms` is near 0 (a few hundred ms to a couple seconds, not the Step 3 value).

- [ ] **Step 5: Verify the log line**

Run: `tail -1 ~/logs/idle-shutdown.log`
Expected: a line matching `<date>: Simulated keypress to extend idle timer (ttys: tty1 ...)`.

- [ ] **Step 6: Verify the no-logged-in-ttys exit path**

Run: `who | grep "^${USER} "` to confirm at least one real tty is currently listed (should be, since you're testing interactively) — this step is a read-only sanity check, not a live negative test (logging everyone out to test the empty-`TTYS` branch isn't practical). Confirm by inspection of the script that an empty `$TTYS` short-circuits to the `exit 1` branch before the `while read` loop runs.

- [ ] **Step 7: Commit**

```bash
cd ~/gitpersonal/dotfiles
cp ~/scripts/idle-extend.sh home/madhur/scripts/idle-extend.sh
git add home/madhur/scripts/idle-extend.sh
git commit -m "$(cat <<'EOF'
Add idle-extend.sh: reset idle timer via simulated keypress

Uses TIOCSTI to inject a NUL byte into each logged-in tty's input
queue, bumping its atime the same way a real keypress would. No
override/snooze logic, no GUI/X11 dependency — works in text-mode
console sessions, which is the expected environment when extending
remotely.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `idle-alert-lib.sh` — one-time pre-shutdown alert, unit-tested

**Files:**
- Create: `/home/madhur/scripts/idle-alert-lib.sh`
- Create: `/home/madhur/scripts/tests/test-idle-alert-lib.sh`

**Interfaces:**
- Produces: `maybe_send_idle_alert(remaining_min)` — a shell function. Reads/writes `$ALERT_STATE_FILE` (default `$HOME/.local/state/idle-shutdown-alerted`, overridable by env var for testing). Invokes `$NTFY_CMD` (default `/home/madhur/.virtualenvs/python-rsha/bin/homelab-ntfy`, overridable by env var for testing) with `--topic bootup --priority urgent --click https://olivetin.desktop.madhur.co.in --title "..." "..."` exactly once per idle streak when `remaining_min <= 5`, and removes the state file when `remaining_min > 5`.
- Consumes: nothing from Task 1.

- [ ] **Step 1: Write the library**

```bash
#!/bin/bash
#
# idle-alert-lib.sh
#
# Fires a one-time ntfy push when remaining idle time first drops to
# <= ALERT_THRESHOLD_MIN, deduped via a state file so it doesn't refire
# every minute while remaining stays low. The state file is cleared once
# remaining goes back above the threshold (real activity or a successful
# extend), re-arming the alert for the next idle streak.

ALERT_STATE_FILE="${ALERT_STATE_FILE:-$HOME/.local/state/idle-shutdown-alerted}"
ALERT_THRESHOLD_MIN="${ALERT_THRESHOLD_MIN:-5}"
NTFY_CMD="${NTFY_CMD:-/home/madhur/.virtualenvs/python-rsha/bin/homelab-ntfy}"
NTFY_CLICK_URL="${NTFY_CLICK_URL:-https://olivetin.desktop.madhur.co.in}"

maybe_send_idle_alert() {
    local remaining_min="$1"
    mkdir -p "$(dirname "$ALERT_STATE_FILE")"

    if [ "$remaining_min" -le "$ALERT_THRESHOLD_MIN" ]; then
        if [ ! -f "$ALERT_STATE_FILE" ]; then
            "$NTFY_CMD" --topic bootup --priority urgent \
                --click "$NTFY_CLICK_URL" \
                --title "Shutting down in ~${remaining_min} min (idle)" \
                "Idle timer will shut this machine down soon. Tap to open OliveTin and extend."
            touch "$ALERT_STATE_FILE"
        fi
    else
        rm -f "$ALERT_STATE_FILE"
    fi
}
```

- [ ] **Step 2: Write the failing test**

```bash
#!/bin/bash
#
# Unit tests for idle-alert-lib.sh, using a stubbed NTFY_CMD so no real
# network call is made. Run directly: bash ~/scripts/tests/test-idle-alert-lib.sh

set -u
FAILURES=0

run_test() {
    local name="$1"
    if "$2"; then
        echo "PASS: $name"
    else
        echo "FAIL: $name"
        FAILURES=$((FAILURES + 1))
    fi
}

setup() {
    TMPDIR_TEST=$(mktemp -d)
    export ALERT_STATE_FILE="$TMPDIR_TEST/state/idle-shutdown-alerted"
    export NTFY_CALL_LOG="$TMPDIR_TEST/ntfy-calls.log"
    NTFY_STUB="$TMPDIR_TEST/homelab-ntfy-stub.sh"
    cat > "$NTFY_STUB" <<'STUB'
#!/bin/bash
echo "$@" >> "$NTFY_CALL_LOG"
STUB
    chmod +x "$NTFY_STUB"
    export NTFY_CMD="$NTFY_STUB"
    source ~/scripts/idle-alert-lib.sh
}

teardown() {
    rm -rf "$TMPDIR_TEST"
}

test_sends_alert_when_at_or_below_threshold() {
    setup
    maybe_send_idle_alert 3
    local result=1
    [ -f "$ALERT_STATE_FILE" ] && [ "$(wc -l < "$NTFY_CALL_LOG")" -eq 1 ] && result=0
    teardown
    return $result
}

test_does_not_resend_while_still_below_threshold() {
    setup
    maybe_send_idle_alert 3
    maybe_send_idle_alert 2
    maybe_send_idle_alert 1
    local result=1
    [ "$(wc -l < "$NTFY_CALL_LOG")" -eq 1 ] && result=0
    teardown
    return $result
}

test_clears_state_file_when_above_threshold() {
    setup
    maybe_send_idle_alert 3
    maybe_send_idle_alert 10
    local result=1
    [ ! -f "$ALERT_STATE_FILE" ] && result=0
    teardown
    return $result
}

test_rearms_after_clearing() {
    setup
    maybe_send_idle_alert 3
    maybe_send_idle_alert 10
    maybe_send_idle_alert 4
    local result=1
    [ -f "$ALERT_STATE_FILE" ] && [ "$(wc -l < "$NTFY_CALL_LOG")" -eq 2 ] && result=0
    teardown
    return $result
}

test_never_sends_when_started_above_threshold() {
    setup
    maybe_send_idle_alert 30
    local result=1
    [ ! -f "$ALERT_STATE_FILE" ] && [ ! -f "$NTFY_CALL_LOG" ] && result=0
    teardown
    return $result
}

run_test "sends alert when at/below threshold" test_sends_alert_when_at_or_below_threshold
run_test "does not resend while still below threshold" test_does_not_resend_while_still_below_threshold
run_test "clears state file when above threshold" test_clears_state_file_when_above_threshold
run_test "rearms after clearing" test_rearms_after_clearing
run_test "never sends when started above threshold" test_never_sends_when_started_above_threshold

if [ "$FAILURES" -gt 0 ]; then
    echo "$FAILURES test(s) failed"
    exit 1
fi
echo "All tests passed"
exit 0
```

- [ ] **Step 3: Run the test to verify it fails (library doesn't exist yet)**

Run: `mkdir -p ~/scripts/tests && bash ~/scripts/tests/test-idle-alert-lib.sh`
Expected: FAIL — `source ~/scripts/idle-alert-lib.sh` errors with "No such file or directory", all 5 tests report FAIL.

- [ ] **Step 4: Create the library from Step 1's content**

Save the Step 1 script to `~/scripts/idle-alert-lib.sh` and run:
Run: `chmod +x ~/scripts/idle-alert-lib.sh`

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash ~/scripts/tests/test-idle-alert-lib.sh`
Expected:
```
PASS: sends alert when at/below threshold
PASS: does not resend while still below threshold
PASS: clears state file when above threshold
PASS: rearms after clearing
PASS: never sends when started above threshold
All tests passed
```

- [ ] **Step 6: Commit**

```bash
cd ~/gitpersonal/dotfiles
mkdir -p home/madhur/scripts/tests
cp ~/scripts/idle-alert-lib.sh home/madhur/scripts/idle-alert-lib.sh
cp ~/scripts/tests/test-idle-alert-lib.sh home/madhur/scripts/tests/test-idle-alert-lib.sh
git add home/madhur/scripts/idle-alert-lib.sh home/madhur/scripts/tests/test-idle-alert-lib.sh
git commit -m "$(cat <<'EOF'
Add idle-alert-lib.sh: one-time pre-shutdown ntfy alert

maybe_send_idle_alert() fires once per idle streak when remaining
time drops to <= 5 min, deduped via a state file that self-clears
once remaining rises back above the threshold. Unit-tested with a
stubbed notifier, no real network calls.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Wire the alert into `idle-shutdown.sh`

**Files:**
- Modify: `/home/madhur/scripts/idle-shutdown.sh:39-43` (right after the existing `IDLE_MINUTES` computation and log line, before the shutdown threshold check)

**Interfaces:**
- Consumes: `maybe_send_idle_alert(remaining_min)` from Task 2's `~/scripts/idle-alert-lib.sh`.

- [ ] **Step 1: Read the current surrounding lines to confirm the exact insertion point**

Run: `grep -n "IDLE_MINUTES\|Log the check\|Check if idle time exceeds" ~/scripts/idle-shutdown.sh`
Expected output includes (line numbers may already match the version read earlier in this session):
```
40:IDLE_MINUTES=$((IDLE_TIME_MS / 60000))
42:# Log the check
43:echo "$(date): Idle time: ${IDLE_MINUTES} minutes (${IDLE_TIME_MS} ms)" >> "$LOG_FILE"
```

- [ ] **Step 2: Insert the remaining-time computation and alert call**

Edit `~/scripts/idle-shutdown.sh` immediately after the `IDLE_MINUTES=...` line (and before the `# Log the check` comment), inserting:

```bash

# Remaining time until shutdown, clamped to >= 0 (mirrors idle-remaining.sh)
REMAINING_MS=$(( THRESHOLD_MS - IDLE_TIME_MS ))
REMAINING_MINUTES=$(( REMAINING_MS / 60000 ))
if [ "$REMAINING_MINUTES" -lt 0 ]; then
    REMAINING_MINUTES=0
fi

# One-time alert when remaining time first drops to <= 5 minutes
source ~/scripts/idle-alert-lib.sh
maybe_send_idle_alert "$REMAINING_MINUTES"
```

The full block, in order, should now read:

```bash
# Convert to minutes for logging
IDLE_MINUTES=$((IDLE_TIME_MS / 60000))

# Remaining time until shutdown, clamped to >= 0 (mirrors idle-remaining.sh)
REMAINING_MS=$(( THRESHOLD_MS - IDLE_TIME_MS ))
REMAINING_MINUTES=$(( REMAINING_MS / 60000 ))
if [ "$REMAINING_MINUTES" -lt 0 ]; then
    REMAINING_MINUTES=0
fi

# One-time alert when remaining time first drops to <= 5 minutes
source ~/scripts/idle-alert-lib.sh
maybe_send_idle_alert "$REMAINING_MINUTES"

# Log the check
echo "$(date): Idle time: ${IDLE_MINUTES} minutes (${IDLE_TIME_MS} ms)" >> "$LOG_FILE"
```

- [ ] **Step 3: Verify the script still runs cleanly with idle time well above the alert threshold**

Run: `~/scripts/idle-extend.sh` (resets idle to ~0, so remaining ≈ 60 min, well above the 5-min alert threshold) then `bash ~/scripts/idle-shutdown.sh; echo "exit=$?"`
Expected: `exit=0`, `tail -2 ~/logs/idle-shutdown.log` shows the normal "System active" line, and `ls ~/.local/state/idle-shutdown-alerted 2>&1` reports "No such file or directory" (no alert fired, nothing to clear since it never existed).

- [ ] **Step 4: Verify the alert fires when remaining is forced below threshold**

Temporarily test with a lowered threshold rather than waiting ~55 minutes:
Run: `THRESHOLD_MS=300000 bash -c 'source ~/scripts/idle-lib.sh; get_idle_ms; echo "idle_ms=$IDLE_MS"'` to confirm current idle in ms, then run the real script with an overridden threshold by temporarily editing `THRESHOLD_MS` is not desirable (don't hand-edit for a one-off test). Instead, directly unit-check the wiring without running the full script:
Run:
```bash
export ALERT_STATE_FILE=/tmp/test-idle-shutdown-alerted
export NTFY_CMD=/bin/echo
rm -f "$ALERT_STATE_FILE"
source ~/scripts/idle-alert-lib.sh
REMAINING_MINUTES=3
maybe_send_idle_alert "$REMAINING_MINUTES"
[ -f "$ALERT_STATE_FILE" ] && echo "STATE FILE CREATED: OK"
rm -f "$ALERT_STATE_FILE"
```
Expected: prints the `homelab-ntfy`-style args (via the `/bin/echo` stub) followed by `STATE FILE CREATED: OK`. This confirms `idle-shutdown.sh`'s new block calls the function with the right argument shape — Task 2's own test suite already covers `maybe_send_idle_alert`'s internal correctness in isolation, so this step only needs to confirm the integration point, not re-prove the library.

- [ ] **Step 5: Commit**

```bash
cd ~/gitpersonal/dotfiles
cp ~/scripts/idle-shutdown.sh home/madhur/scripts/idle-shutdown.sh
git add home/madhur/scripts/idle-shutdown.sh
git commit -m "$(cat <<'EOF'
Wire one-time pre-shutdown alert into idle-shutdown.sh

Computes REMAINING_MINUTES each tick and calls
idle-alert-lib.sh's maybe_send_idle_alert(), so a single ntfy push
fires the first time remaining time drops to <= 5 minutes.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: OliveTin actions — extend, and live remaining-time status

**Files:**
- Modify: `/home/madhur/docker/olivetin/OliveTin-config/config.yaml` (the "Check Idle Shutdown Status" action, and a new action added directly after it)

**Interfaces:**
- Consumes: `~/scripts/idle-extend.sh` (Task 1) and `~/scripts/idle-remaining-plain.sh` (pre-existing, unchanged) over the existing SSH pattern (`ssh -F /config/ssh/easy.cfg madhur@local.madhur.co.in '...'`).

- [ ] **Step 1: Replace the "Check Idle Shutdown Status" action's shell command**

Find this existing block in `~/docker/olivetin/OliveTin-config/config.yaml`:

```yaml
  - title: "Check Idle Shutdown Status"
    icon: "&#128336;"
    shell: ssh -F /config/ssh/easy.cfg madhur@local.madhur.co.in 'if systemctl --user is-active --quiet idle-shutdown.timer; then echo "Idle Shutdown is ENABLED"; else echo "Idle Shutdown is DISABLED"; fi'
    timeout: 30
```

Replace it with:

```yaml
  - title: "Check Idle Shutdown Status"
    icon: "&#128336;"
    shell: ssh -F /config/ssh/easy.cfg madhur@local.madhur.co.in 'if systemctl --user is-active --quiet idle-shutdown.timer; then echo "Idle Shutdown is ENABLED, remaining: $(~/scripts/idle-remaining-plain.sh)"; else echo "Idle Shutdown is DISABLED"; fi'
    timeout: 30
```

- [ ] **Step 2: Add the new "Extend Idle Shutdown" action directly after it**

Insert immediately after the block from Step 1:

```yaml

  - title: "Extend Idle Shutdown"
    icon: "&#9203;"
    shell: ssh -F /config/ssh/easy.cfg madhur@local.madhur.co.in '~/scripts/idle-extend.sh && echo "Idle timer extended" || echo "Extend failed: no logged-in ttys found"'
    timeout: 30
```

- [ ] **Step 3: Add "Extend Idle Shutdown" to the dashboards**

In the `dashboards:` section, find the `Home` dashboard's `Quick Actions` fieldset:

```yaml
  - title: Home
    contents:
      - title: Quick Actions
        type: fieldset
        contents:
          - title: "Enable Idle Shutdown"
          - title: "Disable Idle Shutdown"
          - title: "Shutdown System"
          - title: "Download Teams Video (yt-dlp)"
```

Replace with:

```yaml
  - title: Home
    contents:
      - title: Quick Actions
        type: fieldset
        contents:
          - title: "Enable Idle Shutdown"
          - title: "Disable Idle Shutdown"
          - title: "Extend Idle Shutdown"
          - title: "Shutdown System"
          - title: "Download Teams Video (yt-dlp)"
```

Then find the `Desktop & System` dashboard's `Power` fieldset:

```yaml
      - title: Power
        type: fieldset
        contents:
          - title: "Shutdown System"
          - title: "Enable Idle Shutdown"
          - title: "Disable Idle Shutdown"
          - title: "Check Idle Shutdown Status"
```

Replace with:

```yaml
      - title: Power
        type: fieldset
        contents:
          - title: "Shutdown System"
          - title: "Enable Idle Shutdown"
          - title: "Disable Idle Shutdown"
          - title: "Extend Idle Shutdown"
          - title: "Check Idle Shutdown Status"
```

- [ ] **Step 4: Validate the YAML**

Run: `docker run --rm -v ~/docker/olivetin/OliveTin-config/config.yaml:/tmp/config.yaml python:3-slim python3 -c "import yaml; yaml.safe_load(open('/tmp/config.yaml'))" && echo "YAML OK"`
Expected: `YAML OK` (no exception).

- [ ] **Step 5: Restart OliveTin and verify the actions over SSH directly (bypassing the UI)**

Run: `cd ~/docker/olivetin && docker compose up -d --force-recreate`
Expected: container recreated, `docker ps --filter name=olivetin` shows it `Up`.

Run: `ssh -F ~/docker/olivetin/OliveTin-config/ssh/easy.cfg madhur@local.madhur.co.in 'if systemctl --user is-active --quiet idle-shutdown.timer; then echo "Idle Shutdown is ENABLED, remaining: $(~/scripts/idle-remaining-plain.sh)"; else echo "Idle Shutdown is DISABLED"; fi'`
Expected: `Idle Shutdown is DISABLED` (matches current real state) or, if enabled, `Idle Shutdown is ENABLED, remaining: [⏻ NNm]`.

Run: `ssh -F ~/docker/olivetin/OliveTin-config/ssh/easy.cfg madhur@local.madhur.co.in '~/scripts/idle-extend.sh && echo "Idle timer extended" || echo "Extend failed: no logged-in ttys found"'`
Expected: `Idle timer extended`.

- [ ] **Step 6: Verify in the OliveTin UI**

Open `https://olivetin.desktop.madhur.co.in`, go to the Home dashboard, confirm "Extend Idle Shutdown" appears next to Enable/Disable, click it, confirm it reports success. Go to Desktop & System → Power, click "Check Idle Shutdown Status", confirm the remaining-minutes text appears in the result.

- [ ] **Step 7: Commit**

`~/docker` is tracked in its own separate git repository (not under `~/gitpersonal/dotfiles`) — verify that before committing:

Run: `git -C ~/docker rev-parse --show-toplevel`
Expected: `/home/madhur/docker`

Then commit in the correct repo:

```bash
cd ~/docker
git add olivetin/OliveTin-config/config.yaml
git commit -m "$(cat <<'EOF'
Add Extend Idle Shutdown action, show live remaining time in status

Extend runs the new idle-extend.sh over SSH (simulated keypress,
text-mode safe). Check Idle Shutdown Status now reports remaining
minutes instead of just enabled/disabled.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**Spec coverage:**
- Extend via simulated keypress → Task 1 (`idle-extend.sh`) + Task 4 Step 2 (OliveTin action). ✓
- Live remaining time on demand → Task 4 Step 1 (Check Idle Shutdown Status upgrade). ✓
- One-time 5-minute pre-shutdown alert → Task 2 (`idle-alert-lib.sh` + tests) + Task 3 (wiring into `idle-shutdown.sh`). ✓
- ntfy topic `bootup`, `--click` to OliveTin, no auth bypass → encoded directly in Task 2 Step 1's library code and Global Constraints. ✓
- Explicitly out of scope (DISPLAY bug, dashboard widget, in-notification extend button) → not touched by any task. ✓

**Placeholder scan:** No TBD/TODO markers; every step has literal, runnable code or commands with concrete expected output.

**Type/name consistency:** `maybe_send_idle_alert(remaining_min)` — same name and single positional argument in Task 2 (definition + tests) and Task 3 (call site `maybe_send_idle_alert "$REMAINING_MINUTES"`). `ALERT_STATE_FILE`, `NTFY_CMD`, `NTFY_CLICK_URL`, `ALERT_THRESHOLD_MIN` env-var names match between the library and the test stub. `idle-extend.sh` and `idle-remaining-plain.sh` paths referenced identically in Task 1/2/3 and in Task 4's OliveTin `shell:` commands (`~/scripts/idle-extend.sh`, `~/scripts/idle-remaining-plain.sh`).

**Note on repo layout:** Tasks 1–3 write live files under `~/scripts/` (the machine's real, actively-used copies — confirmed during brainstorming that `idle-shutdown.sh` etc. run from here, not from the dotfiles checkout) and then copy into `~/gitpersonal/dotfiles/home/madhur/scripts/...` for commit, matching that repo's existing mirrored layout (`home/madhur/scripts/idle-shutdown.sh` already exists there). Task 4 edits `~/docker/...` directly since that path is its own separate git repo.
