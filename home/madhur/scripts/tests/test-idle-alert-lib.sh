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
