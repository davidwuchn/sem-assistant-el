#!/bin/sh

set -eu

ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
START_SCRIPT="$ROOT_DIR/dev/start-cron"

PASS_COUNT=0
FAIL_COUNT=0

create_mocks() {
  mock_dir="$1"

  cat >"$mock_dir/chmod" <<'EOF'
#!/bin/sh
exit 0
EOF

  cat >"$mock_dir/service" <<'EOF'
#!/bin/sh
printf 'service %s\n' "$*" >>"${MOCK_CALL_LOG:?}"
exit 0
EOF

  cat >"$mock_dir/eask" <<'EOF'
#!/bin/sh
printf 'eask %s\n' "$*" >>"${MOCK_CALL_LOG:?}"
exit 0
EOF

  cat >"$mock_dir/emacsclient" <<'EOF'
#!/bin/sh
counter_file="${MOCK_COUNTER_FILE:?}"
count=0
if [ -f "$counter_file" ]; then
  count="$(cat "$counter_file")"
fi
count=$((count + 1))
printf '%s\n' "$count" >"$counter_file"

ready_after="${MOCK_READY_AFTER:-1}"
if [ "$count" -ge "$ready_after" ]; then
  printf 't\n'
else
  printf 'nil\n'
fi
exit 0
EOF

  cat >"$mock_dir/sleep" <<'EOF'
#!/bin/sh
printf 'sleep %s\n' "$*" >>"${MOCK_CALL_LOG:?}"
exit 0
EOF

  cat >"$mock_dir/tail" <<'EOF'
#!/bin/sh
printf 'tail %s\n' "$*" >>"${MOCK_CALL_LOG:?}"
exit 0
EOF

  chmod +x "$mock_dir/chmod" "$mock_dir/service" "$mock_dir/eask" \
    "$mock_dir/emacsclient" "$mock_dir/sleep" "$mock_dir/tail"
}

run_start_cron() {
  output_file="$1"
  shift
  (
    export PATH="$MOCK_BIN:$PATH"
    export MOCK_CALL_LOG
    export MOCK_COUNTER_FILE
    "$@" sh "$START_SCRIPT"
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

test_start_cron_waits_for_readiness_before_tail() {
  output="$TMP_DIR/readiness-success.log"
  : >"$MOCK_CALL_LOG"
  : >"$MOCK_COUNTER_FILE"

  run_start_cron "$output" env MOCK_READY_AFTER=2 SEM_DAEMON_READY_MAX_ATTEMPTS=3 SEM_DAEMON_READY_SLEEP_SEC=0
  assert_contains "$MOCK_CALL_LOG" "sleep 0" \
    && assert_contains "$MOCK_CALL_LOG" "tail -F /var/log/cron.log"
}

test_start_cron_fails_fast_when_readiness_times_out() {
  output="$TMP_DIR/readiness-timeout.log"
  : >"$MOCK_CALL_LOG"
  : >"$MOCK_COUNTER_FILE"

  if run_start_cron "$output" env MOCK_READY_AFTER=999 SEM_DAEMON_READY_MAX_ATTEMPTS=2 SEM_DAEMON_READY_SLEEP_SEC=0; then
    return 1
  fi

  assert_contains "$output" "startup readiness failed" \
    && ! assert_contains "$MOCK_CALL_LOG" "tail -F /var/log/cron.log"
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM
MOCK_BIN="$TMP_DIR/bin"
mkdir -p "$MOCK_BIN"
MOCK_CALL_LOG="$TMP_DIR/calls.log"
MOCK_COUNTER_FILE="$TMP_DIR/counter"
touch "$MOCK_CALL_LOG" "$MOCK_COUNTER_FILE"

create_mocks "$MOCK_BIN"

run_test "readiness success enters keepalive" test_start_cron_waits_for_readiness_before_tail
run_test "readiness timeout exits without keepalive" test_start_cron_fails_fast_when_readiness_times_out

printf 'Tests passed: %s\n' "$PASS_COUNT"
printf 'Tests failed: %s\n' "$FAIL_COUNT"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
