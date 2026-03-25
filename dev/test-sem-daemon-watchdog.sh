#!/bin/sh

set -eu

ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
WATCHDOG_SCRIPT="$ROOT_DIR/dev/sem-daemon-watchdog"

PASS_COUNT=0
FAIL_COUNT=0

create_mocks() {
  mock_dir="$1"

  cat >"$mock_dir/date" <<'EOF'
#!/bin/sh
if [ "$1" = "+%s" ]; then
  printf '%s\n' "${MOCK_NOW_EPOCH:-1000}"
else
  printf '%s\n' "${MOCK_TIMESTAMP:-2026-03-25T00:00:00Z}"
fi
EOF

  cat >"$mock_dir/stat" <<'EOF'
#!/bin/sh
if [ "${MOCK_STAT_FAIL:-0}" = "1" ]; then
  exit 1
fi
printf '%s\n' "${MOCK_START_EPOCH:-900}"
EOF

  cat >"$mock_dir/flock" <<'EOF'
#!/bin/sh
if [ "${MOCK_FLOCK_FAIL:-0}" = "1" ]; then
  exit 1
fi
exit 0
EOF

  cat >"$mock_dir/timeout" <<'EOF'
#!/bin/sh
duration="$1"
shift
if [ "${MOCK_TIMEOUT_EXIT:-0}" = "124" ]; then
  exit 124
fi
"$@"
EOF

  cat >"$mock_dir/emacsclient" <<'EOF'
#!/bin/sh
if [ "${MOCK_EMACSCLIENT_EXIT:-0}" = "0" ]; then
  exit 0
fi
exit "${MOCK_EMACSCLIENT_EXIT}"
EOF

  cat >"$mock_dir/pgrep" <<'EOF'
#!/bin/sh
if [ -n "${MOCK_KEEPALIVE_PID:-}" ]; then
  printf '%s\n' "$MOCK_KEEPALIVE_PID"
  exit 0
fi
exit 1
EOF

  cat >"$mock_dir/kill" <<'EOF'
#!/bin/sh
printf '%s\n' "$1" >>"${MOCK_KILL_LOG:?}"
exit 0
EOF

  chmod +x "$mock_dir/date" "$mock_dir/stat" "$mock_dir/flock" \
    "$mock_dir/timeout" "$mock_dir/emacsclient" "$mock_dir/pgrep" "$mock_dir/kill"
}

run_watchdog() {
  output_file="$1"
  shift
  (
    export PATH="$MOCK_BIN:$PATH"
    export MOCK_KILL_LOG
    export SEM_WATCHDOG_LOCK_FILE="$TMP_DIR/lockfile"
    export SEM_WATCHDOG_KILL_COMMAND="$MOCK_BIN/kill"
    "$@" "$WATCHDOG_SCRIPT"
  ) >"$output_file" 2>&1
}

assert_contains() {
  file="$1"
  text="$2"
  if grep -q "$text" "$file"; then
    return 0
  fi
  return 1
}

run_test() {
  name="$1"
  test_fn="$2"
  if "$test_fn"; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf 'PASS %s\n' "$name"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf 'FAIL %s\n' "$name"
  fi
}

test_probe_success() {
  output="$TMP_DIR/success.log"
  : >"$MOCK_KILL_LOG"
  run_watchdog "$output" env MOCK_EMACSCLIENT_EXIT=0
  assert_contains "$output" "event=PROBE_OK" && [ ! -s "$MOCK_KILL_LOG" ]
}

test_probe_timeout_triggers_restart() {
  output="$TMP_DIR/timeout.log"
  : >"$MOCK_KILL_LOG"
  run_watchdog "$output" env MOCK_TIMEOUT_EXIT=124 MOCK_KEEPALIVE_PID=2222 \
    MOCK_NOW_EPOCH=2000 MOCK_START_EPOCH=1000
  assert_contains "$output" "event=PROBE_FAIL" \
    && assert_contains "$output" "event=RESTART_TRIGGERED" \
    && assert_contains "$MOCK_KILL_LOG" "2222"
}

test_grace_suppresses_restart() {
  output="$TMP_DIR/grace.log"
  : >"$MOCK_KILL_LOG"
  run_watchdog "$output" env MOCK_EMACSCLIENT_EXIT=1 MOCK_NOW_EPOCH=1000 MOCK_START_EPOCH=980 \
    SEM_WATCHDOG_STARTUP_GRACE_SEC=60
  assert_contains "$output" "event=RESTART_SUPPRESSED_GRACE" && [ ! -s "$MOCK_KILL_LOG" ]
}

test_lock_contention_skips() {
  output="$TMP_DIR/lock.log"
  : >"$MOCK_KILL_LOG"
  run_watchdog "$output" env MOCK_FLOCK_FAIL=1
  assert_contains "$output" "event=LOCK_CONTENTION_SKIP"
}

test_restart_idempotent_when_keepalive_absent() {
  output="$TMP_DIR/idempotent.log"
  : >"$MOCK_KILL_LOG"
  run_watchdog "$output" env MOCK_EMACSCLIENT_EXIT=1 MOCK_KEEPALIVE_PID= \
    MOCK_NOW_EPOCH=2000 MOCK_START_EPOCH=1000
  assert_contains "$output" "event=RESTART_ALREADY_SATISFIED" && [ ! -s "$MOCK_KILL_LOG" ]
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM
MOCK_BIN="$TMP_DIR/bin"
mkdir -p "$MOCK_BIN"
MOCK_KILL_LOG="$TMP_DIR/kill.log"
touch "$MOCK_KILL_LOG"

create_mocks "$MOCK_BIN"

run_test "probe success" test_probe_success
run_test "probe timeout restart" test_probe_timeout_triggers_restart
run_test "startup grace suppression" test_grace_suppresses_restart
run_test "lock contention skip" test_lock_contention_skips
run_test "idempotent restart" test_restart_idempotent_when_keepalive_absent

printf 'Tests passed: %s\n' "$PASS_COUNT"
printf 'Tests failed: %s\n' "$FAIL_COUNT"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
