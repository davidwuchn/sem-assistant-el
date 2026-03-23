#!/bin/bash
# Integration Test Runner for SEM Assistant Elisp Daemon
# Executes the full integration test lifecycle end-to-end

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMPOSE_FILE="$REPO_ROOT/docker-compose.yml"
COMPOSE_OVERRIDE="$SCRIPT_DIR/docker-compose.test.yml"
TEST_INBOX="$SCRIPT_DIR/testing-resources/inbox-tasks.org"
TEST_DATA_DIR="$REPO_ROOT/test-data"
TEST_RESULTS_DIR="$REPO_ROOT/test-results"
LOGS_DIR="$REPO_ROOT/logs"
WEBDAV_BASE_URL="http://localhost:16065"
WEBDAV_USERNAME="${WEBDAV_USERNAME:-orgzly}"
WEBDAV_PASSWORD="${WEBDAV_PASSWORD:-changeme}"

# Test-specific port mapping (avoids privileged port 443)
export WEBDAV_PORT=16065

# Test-specific model name
export OPENROUTER_MODEL="qwen/qwen3.5-35b-a3b"

# Poll configuration
DAEMON_POLL_INTERVAL=3
DAEMON_MAX_ATTEMPTS=30
TASKS_POLL_INTERVAL=5
TASKS_MAX_ATTEMPTS=24

# Derived: expected task count from test inbox (count :task: headlines)
# IMPORTANT: When adding/removing task headlines in the test inbox,
# this value is derived automatically and used for polling and assertions.
EXPECTED_TASK_COUNT=$(grep -c '^\* TODO .*:task:' "$TEST_INBOX" 2>/dev/null || echo "0")

# Test status
TEST_STATUS="PASS"
RUN_DIR=""

# =============================================================================
# Validation
# =============================================================================

# Check OPENROUTER_KEY is set
if [[ -z "${OPENROUTER_KEY:-}" ]]; then
    echo "ERROR: OPENROUTER_KEY environment variable is not set" >&2
    echo "Integration tests require real LLM API access." >&2
    exit 1
fi

echo "=== SEM Integration Test Suite ==="
echo "OPENROUTER_KEY is set (masked)"

# =============================================================================
# Cleanup Trap (MUST be registered early, before any other actions)
# =============================================================================

cleanup() {
    echo ""
    echo "=== Cleanup ==="
    echo "Stopping containers..."
    podman-compose -f "$COMPOSE_FILE" -f "$COMPOSE_OVERRIDE" down -v 2>/dev/null || true
    echo "Removing dangling images..."
    podman image prune -f 2>/dev/null || true
    echo "Cleanup complete"
}

trap cleanup EXIT

# =============================================================================
# Test Data Directory Setup
# =============================================================================

cleanup_test_results() {
    echo ""
    echo "=== Cleaning Up Test Results Directory ==="
    
    if [[ -d "$TEST_RESULTS_DIR" ]]; then
        echo "Removing existing test-results directory..."
        rm -rf "$TEST_RESULTS_DIR"
    fi
    
    echo "Creating fresh test-results directory..."
    mkdir -p "$TEST_RESULTS_DIR"
    
    echo "Test results directory ready: $TEST_RESULTS_DIR"
}

setup_test_data() {
    echo ""
    echo "=== Setting Up Test Data Directory ==="
    
    # Wipe test-data if it exists
    if [[ -d "$TEST_DATA_DIR" ]]; then
        echo "Removing existing test-data directory..."
        rm -rf "$TEST_DATA_DIR"
    fi
    
    # Recreate with required subdirectories
    echo "Creating test-data subdirectories..."
    mkdir -p "$TEST_DATA_DIR/org-roam"
    mkdir -p "$TEST_DATA_DIR/elfeed"
    mkdir -p "$TEST_DATA_DIR/morning-read"
    mkdir -p "$TEST_DATA_DIR/prompts"
    
    echo "Test data directory ready: $TEST_DATA_DIR"
}

# =============================================================================
# Logs Directory Setup
# =============================================================================

setup_logs() {
    echo ""
    echo "=== Setting Up Logs Directory ==="
    
    # Wipe logs directory
    if [[ -d "$LOGS_DIR" ]]; then
        echo "Removing existing logs..."
        rm -rf "$LOGS_DIR"/*
    else
        mkdir -p "$LOGS_DIR"
    fi
    
    echo "Logs directory ready: $LOGS_DIR"
}

# =============================================================================
# Run Directory Creation
# =============================================================================

create_run_dir() {
    echo ""
    echo "=== Creating Run Directory ==="

    # Create test-results directory if absent
    mkdir -p "$TEST_RESULTS_DIR"

    # Create timestamped run directory
    local timestamp
    timestamp=$(date +%Y-%m-%d-%H-%M-%S)
    RUN_DIR="$TEST_RESULTS_DIR/${timestamp}-run"
    mkdir -p "$RUN_DIR"

    echo "Run directory created: $RUN_DIR"
}

# =============================================================================
# Container Lifecycle
# =============================================================================

start_containers() {
    echo ""
    echo "=== Starting Containers ==="

    cd "$REPO_ROOT"

    echo "Starting containers with test override (rebuilding image)..."
    podman-compose -f "$COMPOSE_FILE" -f "$COMPOSE_OVERRIDE" up -d --build

    echo "Containers started"
}

wait_for_daemon() {
    echo ""
    echo "=== Waiting for Emacs Daemon ==="
    
    local attempt=0
    local ready=false
    
    while [[ $attempt -lt $DAEMON_MAX_ATTEMPTS ]]; do
        attempt=$((attempt + 1))
        echo "Polling daemon (attempt $attempt/$DAEMON_MAX_ATTEMPTS)..."
        
        if podman-compose exec emacs emacsclient -s sem-server --eval 't' &>/dev/null; then
            echo "Daemon is ready!"
            ready=true
            break
        fi
        
        sleep $DAEMON_POLL_INTERVAL
    done
    
    if [[ "$ready" != "true" ]]; then
        echo "ERROR: Emacs daemon failed to become ready after $DAEMON_MAX_ATTEMPTS attempts" >&2
        TEST_STATUS="FAIL"
        return 1
    fi
}

# =============================================================================
# Debug emacsclient connectivity
# =============================================================================

debug_emacsclient() {
    echo ""
    echo "=== Debug: Testing emacsclient connectivity ==="
    
    echo "Running: emacsclient -s sem-server --eval '(message \"EMACSCLIENT: server is up and accessible\")'"
    podman-compose exec emacs emacsclient -s sem-server --eval '(message "EMACSCLIENT: server is up and accessible")'
    
    echo "Debug call complete - check container logs for 'EMACSCLIENT:' message"
}

# =============================================================================
# Cron/emacsclient verification
# =============================================================================

verify_cron_emacsclient() {
    echo ""
    echo "=== Cron/emacsclient Verification ==="
    
    echo "Testing emacsclient can execute scheduled functions..."
    
    local test_result
    test_result=$(podman-compose exec emacs emacsclient -s sem-server --eval '
(progn
  (require (quote sem-core))
  (condition-case err
      (progn
        (message "CRON-VERIFY: Testing sem-core-log availability")
        (if (fboundp (quote sem-core-log))
            (message "CRON-VERIFY: SUCCESS - sem-core-log is available")
          (message "CRON-VERIFY: FAIL - sem-core-log not found"))
        (message "CRON-VERIFY: Testing emacsclient execution successful"))
    (error
     (message "CRON-VERIFY: ERROR - %s" (error-message-string err))))
  t
)' 2>&1)
    
    echo "emacsclient execution result: $test_result"
    
    if echo "$test_result" | grep -q "CRON-VERIFY: SUCCESS"; then
        echo "PASS: emacsclient can execute scheduled commands"
        return 0
    else
        echo "FAIL: emacsclient execution verification failed"
        return 1
    fi
}

# =============================================================================
# Inbox Processing
# =============================================================================

upload_inbox() {
    echo ""
    echo "=== Uploading Test Inbox ==="
    
    echo "Uploading inbox via WebDAV..."
    curl --fail --silent --show-error \
        -u "${WEBDAV_USERNAME}:${WEBDAV_PASSWORD}" \
        -T "$TEST_INBOX" \
        "${WEBDAV_BASE_URL}/inbox-mobile.org"
    
    echo "Inbox uploaded successfully"
    
    echo "Also copying to TEST_DATA_DIR for reference..."
    cp "$TEST_INBOX" "$TEST_DATA_DIR/inbox-mobile.org"
}

verify_inbox_upload() {
    echo ""
    echo "=== Verifying Inbox Upload ==="
    
    local temp_verify
    temp_verify=$(mktemp)
    
    if curl --fail --silent --show-error \
        -u "${WEBDAV_USERNAME}:${WEBDAV_PASSWORD}" \
        -o "$temp_verify" \
        "${WEBDAV_BASE_URL}/inbox-mobile.org" 2>/dev/null; then
        echo "Inbox fetched successfully from WebDAV"
        
        local sent_lines verify_lines
        sent_lines=$(wc -l < "$TEST_INBOX")
        verify_lines=$(wc -l < "$temp_verify")
        echo "Sent file: $sent_lines lines, Fetched file: $verify_lines lines"
        
        if [[ "$sent_lines" -eq "$verify_lines" ]]; then
            echo "PASS: Line count matches"
            echo "Computing checksums for comparison..."
            echo "  Sent file MD5:     $(md5sum "$TEST_INBOX" | awk '{print $1}')"
            echo "  Fetched file MD5:  $(md5sum "$temp_verify" | awk '{print $1}')"
        else
            echo "FAIL: Line count mismatch"
            echo "--- Sent content ---"
            head -5 "$TEST_INBOX"
            echo "--- Fetched content ---"
            head -5 "$temp_verify"
            TEST_STATUS="FAIL"
        fi
    else
        echo "FAIL: Could not fetch inbox from WebDAV"
        TEST_STATUS="FAIL"
    fi
    
    rm -f "$temp_verify"
}

diagnose_inbox_file() {
    echo ""
    echo "=== Diagnosing Inbox File Visibility ==="
    
    # Step 1: Check that emacs can read the file
    echo "[Step 1] Checking if emacs can read /data/inbox-mobile.org..."
    podman-compose exec emacs emacsclient -s sem-server --eval '(message "DIAG-CHECK: Starting file existence check")'
    podman-compose exec emacs emacsclient -s sem-server --eval '(message "DIAG-CHECK: file-exists-p = %s" (file-exists-p "/data/inbox-mobile.org"))'
    podman-compose exec emacs emacsclient -s sem-server --eval '(message "DIAG-CHECK: file-readable-p = %s" (file-readable-p "/data/inbox-mobile.org"))'
    podman-compose exec emacs emacsclient -s sem-server --eval '(message "DIAG-CHECK: file-writable-p = %s" (file-writable-p "/data/inbox-mobile.org"))'
    echo "[Step 1] File existence check complete"
    
    # Step 2: Read the file and write it back with a different name
    echo "[Step 2] Reading inbox-mobile.org and writing copy to inbox-mobile.copy.org..."
    podman-compose exec emacs emacsclient -s sem-server --eval '
(with-temp-buffer
  (let ((src "/data/inbox-mobile.org")
        (dst "/data/inbox-mobile.copy.org"))
    (message "DIAG-COPY: Starting copy operation from %s to %s" src dst)
    (if (file-exists-p src)
        (progn
          (insert-file-contents src)
          (let ((size (point-max)))
            (message "DIAG-COPY: Read %d bytes from source" size)
            (write-region (point-min) (point-max) dst nil (quote silent))
            (message "DIAG-COPY: Wrote %d bytes to destination" size)
            (message "DIAG-COPY: Destination file exists after write: %s" (file-exists-p dst))))
      (message "DIAG-COPY: Source file does not exist, cannot copy")))
  (message "DIAG-COPY: Copy operation complete"))
' 2>&1 || echo "WARNING: file copy operation failed"
    echo "[Step 2] File copy operation complete"
    
    # Step 3: Write full diagnostics (verbose - output to both buffer and stdout via message)
    echo "[Step 3] Writing full diagnostic report..."
    podman-compose exec emacs emacsclient -s sem-server --eval '
(progn
  (require (quote org-element))
  (let ((diag-output ""))
    (cl-flet ((diag-insert (fmt &rest args)
                           (let ((text (apply (function format) (cons fmt args))))
                             (setq diag-output (concat diag-output text "\n")))))
      (diag-insert "=== INBOX DIAGNOSTIC ===")
      (diag-insert "Time: %s" (current-time-string))
      (diag-insert "File exists: %s" (file-exists-p "/data/inbox-mobile.org"))
      (diag-insert "File readable: %s" (file-readable-p "/data/inbox-mobile.org"))
      (diag-insert "File writable: %s" (file-writable-p "/data/inbox-mobile.org"))
      (diag-insert "Copy file exists: %s" (file-exists-p "/data/inbox-mobile.copy.org"))
      (when (file-exists-p "/data/inbox-mobile.org")
        (insert-file-contents "/data/inbox-mobile.org")
        (diag-insert "Buffer size: %d bytes" (point-max))
        (diag-insert "First 300 chars:")
        (diag-insert "%s" (buffer-substring-no-properties (point-min) (min (point-max) 300)))
        (diag-insert "Last 100 chars:")
        (diag-insert "%s" (buffer-substring-no-properties (max (point-min) (- (point-max) 100)) (point-max)))
        (condition-case err
            (progn
              (org-mode)
              (let ((ast (org-element-parse-buffer)))
                (diag-insert "AST parsed OK, root type: %s" (org-element-type ast))
                (let ((headlines (org-element-map ast (quote headline) (lambda (h) h))))
                  (diag-insert "Headline count: %d" (length headlines))
                  (dolist (h headlines)
                    (diag-insert "  - %s | tags: %s"
                             (org-element-property :raw-value h)
                             (org-element-property :tags h))))))
          (error (diag-insert "PARSE ERROR: %s" (error-message-string err))))))
    ;; Write to file
    (with-temp-buffer
      (insert diag-output)
      (write-region nil nil "/data/sem-diag.txt"))
    ;; Also print to stdout via message (will appear in container logs)
    (message "DIAG-VERBOSE:\n%s" diag-output)
    (message "DIAG-VERBOSE: End of diagnostic output")))
' 2>&1 || echo "WARNING: emacsclient diagnose failed"
    echo "[Step 3] Diagnostic report written"
    
    # Fetch the diagnostic file from WebDAV
    echo "Fetching diagnostic file from WebDAV..."
    curl --silent --show-error \
        -u "${WEBDAV_USERNAME}:${WEBDAV_PASSWORD}" \
        -o "$RUN_DIR/sem-diag.txt" \
        "${WEBDAV_BASE_URL}/data/sem-diag.txt" 2>/dev/null || echo "Could not fetch sem-diag.txt"
    
    echo "Diagnostic file saved to: $RUN_DIR/sem-diag.txt"
    echo "=== Diagnostic content ==="
    cat "$RUN_DIR/sem-diag.txt" 2>/dev/null || echo "(empty or not found)"
    echo "=== End diagnostic ==="
}

trigger_inbox_processing() {
    echo ""
    echo "=== Triggering Inbox Processing ==="
    
    echo "Calling sem-core-process-inbox..."
    podman-compose exec emacs emacsclient -s sem-server -e "(sem-core-process-inbox)"
    
    echo "Inbox processing triggered"
}

wait_for_tasks() {
    local expected_count="${1:-0}"
    echo ""
    echo "=== Waiting for Tasks.org (expecting $expected_count tasks) ==="
    
    local attempt=0
    local todo_count=0
    local temp_file
    temp_file=$(mktemp)
    
    while [[ $attempt -lt $TASKS_MAX_ATTEMPTS ]]; do
        attempt=$((attempt + 1))
        echo "Polling tasks.org (attempt $attempt/$TASKS_MAX_ATTEMPTS)..."
        
        # GET tasks.org
        if curl --fail --silent --show-error \
            -u "${WEBDAV_USERNAME}:${WEBDAV_PASSWORD}" \
            -o "$temp_file" \
            "${WEBDAV_BASE_URL}/data/tasks.org" 2>/dev/null; then
            
            # Count TODO entries
            todo_count=$(grep -c '^\* TODO ' "$temp_file" 2>/dev/null || echo "0")
            echo "Found $todo_count TODO entries"
            
            if [[ "$todo_count" -ge "$expected_count" ]]; then
                echo "All $expected_count tasks detected!"
                # Save the temp file as our authoritative tasks.org
                mv "$temp_file" "$RUN_DIR/tasks.org"
                return 0
            fi
        else
            echo "tasks.org not yet available"
        fi
        
        sleep $TASKS_POLL_INTERVAL
    done
    
    # Timeout - save partial results
    echo "WARNING: Poll timeout - tasks.org may be incomplete" >&2
    TEST_STATUS="FAIL"
    
    # Save whatever we got (even if empty/partial)
    if [[ -f "$temp_file" && -s "$temp_file" ]]; then
        mv "$temp_file" "$RUN_DIR/tasks.org"
    else
        touch "$RUN_DIR/tasks.org"
    fi
    
    rm -f "$temp_file"
    return 1
}

# =============================================================================
# Artifact Collection
# =============================================================================

collect_artifacts() {
    echo ""
    echo "=== Collecting Artifacts ==="
    
    # Copy inbox-sent.org (the test inbox we sent)
    echo "Copying inbox-sent.org..."
    cp "$TEST_INBOX" "$RUN_DIR/inbox-sent.org"
    
    # GET tasks.org if not already saved during poll
    if [[ ! -f "$RUN_DIR/tasks.org" ]]; then
        echo "Fetching tasks.org..."
        curl --silent --show-error \
            -u "${WEBDAV_USERNAME}:${WEBDAV_PASSWORD}" \
            -o "$RUN_DIR/tasks.org" \
            "${WEBDAV_BASE_URL}/data/tasks.org" 2>/dev/null || touch "$RUN_DIR/tasks.org"
    fi
    
    # GET sem-log.org
    echo "Fetching sem-log.org..."
    curl --silent --show-error \
        -u "${WEBDAV_USERNAME}:${WEBDAV_PASSWORD}" \
        -o "$RUN_DIR/sem-log.org" \
        "${WEBDAV_BASE_URL}/data/sem-log.org" 2>/dev/null || touch "$RUN_DIR/sem-log.org"
    
    # GET errors.org (may 404 - handle silently)
    echo "Fetching errors.org (may not exist)..."
    if ! curl --fail --silent --show-error \
        -u "${WEBDAV_USERNAME}:${WEBDAV_PASSWORD}" \
        -o "$RUN_DIR/errors.org" \
        "${WEBDAV_BASE_URL}/data/errors.org" 2>/dev/null; then
        echo "errors.org not found (this is OK)"
        touch "$RUN_DIR/errors.org"
    fi
    
    # Copy diagnostic files (may have been created during test)
    echo "Copying diagnostic files..."
    [[ -f "$RUN_DIR/sem-diag.txt" ]] && echo "  sem-diag.txt already present" || echo "  sem-diag.txt not found"
    [[ -f "$RUN_DIR/sem-proc-diag.txt" ]] && echo "  sem-proc-diag.txt already present" || echo "  sem-proc-diag.txt not found"
    [[ -f "$RUN_DIR/container-inbox-mobile.org" ]] && echo "  container-inbox-mobile.org already present" || echo "  container-inbox-mobile.org not found"
    
    # Copy log files from ./logs/
    echo "Copying message logs..."
    if compgen -G "$LOGS_DIR/messages-*.log" > /dev/null; then
        cp "$LOGS_DIR"/messages-*.log "$RUN_DIR/"
    else
        echo "No message logs found"
        touch "$RUN_DIR/messages-none.log"
    fi
    
    # Collect container logs
    echo "Collecting container logs..."
    podman-compose logs emacs > "$RUN_DIR/emacs-container.log" 2>&1 || true
    podman-compose logs webdav > "$RUN_DIR/webdav-container.log" 2>&1 || true
    
    echo "Artifacts collected to: $RUN_DIR"
}

# =============================================================================
# Assertions
# =============================================================================

run_assertions() {
    echo ""
    echo "=== Running Assertions ==="
    
    local validation_file="$RUN_DIR/validation.txt"
    rm -f "$RUN_DIR/assertion-results.txt"
    
    # Assertion 1: TODO count
    echo "Assertion 1: TODO count..."
    {
        echo "=== Assertion 1: TODO Count ==="
        local todo_count
        todo_count=$(grep -c '^\* TODO ' "$RUN_DIR/tasks.org" 2>/dev/null || echo "0")
        echo "Found $todo_count TODO entries (expected: $EXPECTED_TASK_COUNT)"
        
        if [[ "$todo_count" -ne "$EXPECTED_TASK_COUNT" ]]; then
            echo "FAIL: expected $EXPECTED_TASK_COUNT TODO entries, got $todo_count"
            echo "ASSERTION_1_RESULT:FAIL"
        else
            echo "PASS: TODO count is $EXPECTED_TASK_COUNT"
            echo "ASSERTION_1_RESULT:PASS"
        fi
        echo ""
    } | tee -a "$validation_file" | tee -a "$RUN_DIR/assertion-results.txt"
    
    # Assertion 2: Keyword presence
    echo "Assertion 2: Keyword presence..."
    {
        echo "=== Assertion 2: Keyword Presence ==="
        local keywords=("quarterly financial reports" "pull request" "team building activity")
        local keyword_failed=false
        
        for keyword in "${keywords[@]}"; do
            if grep -q "$keyword" "$RUN_DIR/tasks.org" 2>/dev/null; then
                echo "PASS: Found '$keyword'"
            else
                echo "FAIL: Missing keyword '$keyword'"
                keyword_failed=true
            fi
        done
        
        if [[ "$keyword_failed" == "true" ]]; then
            echo "FAIL: Some keywords missing"
            echo "ASSERTION_2_RESULT:FAIL"
        else
            echo "PASS: All keywords present"
            echo "ASSERTION_2_RESULT:PASS"
        fi
        echo ""
    } | tee -a "$validation_file" | tee -a "$RUN_DIR/assertion-results.txt"
    
    # Assertion 3: Org validity
    echo "Assertion 3: Org validity..."
    {
        echo "=== Assertion 3: Org Validity ==="
        
        if emacs --batch \
            --eval "(condition-case err \
                      (progn (find-file \"$RUN_DIR/tasks.org\") \
                             (org-mode) \
                             (org-element-parse-buffer) \
                             (message \"ORG-VALID\")) \
                    (error (error \"ORG-INVALID: %s\" err)))" 2>&1 | grep -q "ORG-VALID"; then
            echo "PASS: tasks.org is valid Org"
            echo "ASSERTION_3_RESULT:PASS"
        else
            echo "FAIL: tasks.org is not valid Org"
            echo "ASSERTION_3_RESULT:FAIL"
        fi
        echo ""
    } | tee -a "$validation_file" | tee -a "$RUN_DIR/assertion-results.txt"
    
    # Assertion 4: Sensitive content restoration
    echo "Assertion 4: Sensitive content restoration..."
    {
        echo "=== Assertion 4: Sensitive Content Restoration ==="
        
        local sensitive_keywords=("supersecret123" "sk-live-abc123xyz789" "IBAN: DE89370400440532013000" "ACCOUNT NUMBER: 123456789")
        local sensitive_failed=false
        
        for keyword in "${sensitive_keywords[@]}"; do
            if grep -q "$keyword" "$RUN_DIR/tasks.org" 2>/dev/null; then
                echo "PASS: Sensitive content restored: '$keyword'"
            else
                echo "FAIL: Sensitive content NOT restored: '$keyword'"
                sensitive_failed=true
            fi
        done
        
        if [[ "$sensitive_failed" == "true" ]]; then
            echo "FAIL: Some sensitive content not restored"
            echo "ASSERTION_4_RESULT:FAIL"
        else
            echo "PASS: All sensitive content properly restored"
            echo "ASSERTION_4_RESULT:PASS"
        fi
        echo ""
    } | tee -a "$validation_file" | tee -a "$RUN_DIR/assertion-results.txt"
    
    # Assertion 4a: Negative marker check - no #+begin_sensitive markers in output
    echo "Assertion 4a: Negative marker check..."
    {
        echo "=== Assertion 4a: Negative Marker Check ==="
        
        if grep -q '#+begin_sensitive' "$RUN_DIR/tasks.org" 2>/dev/null; then
            echo "FAIL: Found '#+begin_sensitive' markers in output - markers should not be present"
            echo "ASSERTION_4A_RESULT:FAIL"
        else
            echo "PASS: No '#+begin_sensitive' markers found in output"
            echo "ASSERTION_4A_RESULT:PASS"
        fi
        echo ""
    } | tee -a "$validation_file" | tee -a "$RUN_DIR/assertion-results.txt"
    
    # Assertion 4b: Order verification - within each task, sensitive content appears in same order as original
    echo "Assertion 4b: Sensitive content within-task order verification..."
    {
        echo "=== Assertion 4b: Sensitive Content Within-Task Order Verification ==="
        
        local tasks_content
        tasks_content=$(cat "$RUN_DIR/tasks.org" 2>/dev/null || echo "")
        
        # For "Update password manager" task: supersecret123 should appear before sk-live-abc123xyz789
        local pos1 pos2 pos3 pos4
        pos1=$(echo "$tasks_content" | grep -n 'supersecret123' | head -1 | cut -d: -f1)
        pos2=$(echo "$tasks_content" | grep -n 'sk-live-abc123xyz789' | head -1 | cut -d: -f1)
        pos3=$(echo "$tasks_content" | grep -n 'IBAN: DE89370400440532013000' | head -1 | cut -d: -f1)
        pos4=$(echo "$tasks_content" | grep -n 'ACCOUNT NUMBER: 123456789' | head -1 | cut -d: -f1)
        
        local order_failed=false
        
        echo "Task 'Update password manager': supersecret123 at line $pos1, sk-live-abc123xyz789 at line $pos2"
        if [[ -n "$pos1" && -n "$pos2" ]]; then
            if [[ "$pos1" -lt "$pos2" ]]; then
                echo "PASS: supersecret123 appears before sk-live-abc123xyz789"
            else
                echo "FAIL: supersecret123 does NOT appear before sk-live-abc123xyz789"
                order_failed=true
            fi
        else
            echo "FAIL: Could not find both keywords in password manager task"
            order_failed=true
        fi
        
        echo "Task 'Process payment to vendor': IBAN at line $pos3, ACCOUNT NUMBER at line $pos4"
        if [[ -n "$pos3" && -n "$pos4" ]]; then
            if [[ "$pos3" -lt "$pos4" ]]; then
                echo "PASS: IBAN appears before ACCOUNT NUMBER"
            else
                echo "FAIL: IBAN does NOT appear before ACCOUNT NUMBER"
                order_failed=true
            fi
        else
            echo "FAIL: Could not find both keywords in payment task"
            order_failed=true
        fi
        
        if [[ "$order_failed" == "true" ]]; then
            echo "ASSERTION_4B_RESULT:FAIL"
        else
            echo "PASS: All sensitive content within-task order correct"
            echo "ASSERTION_4B_RESULT:PASS"
        fi
        
        echo ""
    } | tee -a "$validation_file" | tee -a "$RUN_DIR/assertion-results.txt"
    
    # Assertion 5: SCHEDULED times fall within preferred windows from rules.org
    echo "Assertion 5: SCHEDULED time preference validation..."
    {
        echo "=== Assertion 5: SCHEDULED Time Preference Validation ==="
        
        # Check if tasks.org exists and has scheduled times
        if [[ ! -f "$RUN_DIR/tasks.org" ]] || [[ ! -s "$RUN_DIR/tasks.org" ]]; then
            echo "SKIP: tasks.org does not exist or is empty - cannot validate SCHEDULED times"
            echo "ASSERTION_5_RESULT:SKIP"
        else
            # Read rules to understand preferences
            local rules_file="$SCRIPT_DIR/testing-resources/rules.org"
            if [[ ! -f "$rules_file" ]]; then
                echo "SKIP: rules.org not found - cannot validate preferences"
                echo "ASSERTION_5_RESULT:SKIP"
            else
                # Soft check: validate that SCHEDULED times exist and have time components
                local scheduled_count=0
                local valid_scheduled_count=0
                
                # Count tasks with SCHEDULED that have time components (HH:MM or HH:MM-HH:MM)
                scheduled_count=$(grep -c 'SCHEDULED:' "$RUN_DIR/tasks.org" 2>/dev/null || echo "0")
                
                if [[ "$scheduled_count" -eq 0 ]]; then
                    echo "WARN: No tasks have SCHEDULED times"
                    echo "ASSERTION_5_RESULT:WARN"
                else
                    # Count tasks with time ranges (HH:MM-HH:MM format) or specific times (HH:MM)
                    valid_scheduled_count=$(grep 'SCHEDULED:' "$RUN_DIR/tasks.org" 2>/dev/null | grep -cE 'SCHEDULED: <[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}(-[0-9]{2}:[0-9]{2})?>' || echo "0")
                    
                    echo "Found $scheduled_count tasks with SCHEDULED, $valid_scheduled_count with time components"
                    
                    # Soft assertion: at least some tasks should have time components
                    if [[ "$valid_scheduled_count" -gt 0 ]]; then
                        echo "PASS: Some tasks have time components in SCHEDULED (preference: afternoon for routine, after 4PM for free time)"
                        echo "ASSERTION_5_RESULT:PASS"
                    else
                        echo "WARN: No tasks have time components in SCHEDULED - LLM did not add times"
                        echo "ASSERTION_5_RESULT:WARN"
                    fi
                fi
            fi
        fi
        echo ""
    } | tee -a "$validation_file" | tee -a "$RUN_DIR/assertion-results.txt"
    
    # Final result - read from temp file (avoids subshell variable loss issue)
    echo "=== Final Result ==="
    local final_assertion1 final_assertion2 final_assertion3 final_assertion4 final_assertion4a final_assertion4b final_assertion5
    final_assertion1=$(grep "ASSERTION_1_RESULT:" "$RUN_DIR/assertion-results.txt" | cut -d: -f2)
    final_assertion2=$(grep "ASSERTION_2_RESULT:" "$RUN_DIR/assertion-results.txt" | cut -d: -f2)
    final_assertion3=$(grep "ASSERTION_3_RESULT:" "$RUN_DIR/assertion-results.txt" | cut -d: -f2)
    final_assertion4=$(grep "ASSERTION_4_RESULT:" "$RUN_DIR/assertion-results.txt" | cut -d: -f2)
    final_assertion4a=$(grep "ASSERTION_4A_RESULT:" "$RUN_DIR/assertion-results.txt" | cut -d: -f2)
    final_assertion4b=$(grep "ASSERTION_4B_RESULT:" "$RUN_DIR/assertion-results.txt" | cut -d: -f2)
    final_assertion5=$(grep "ASSERTION_5_RESULT:" "$RUN_DIR/assertion-results.txt" | cut -d: -f2)
    
    if [[ "$final_assertion1" == "PASS" && "$final_assertion2" == "PASS" && "$final_assertion3" == "PASS" && "$final_assertion4" == "PASS" && "$final_assertion4a" == "PASS" && "$final_assertion4b" == "PASS" && "$TEST_STATUS" == "PASS" ]]; then
        echo "ALL ASSERTIONS PASSED"
        exit 0
    else
        echo "SOME ASSERTIONS FAILED"
        echo "  Assertion 1 (TODO count): $final_assertion1"
        echo "  Assertion 2 (Keywords): $final_assertion2"
        echo "  Assertion 3 (Org validity): $final_assertion3"
        echo "  Assertion 4 (Sensitive content): $final_assertion4"
        echo "  Assertion 4a (No markers): $final_assertion4a"
        echo "  Assertion 4b (Order verification): $final_assertion4b"
        echo "  Assertion 5 (SCHEDULED preferences): $final_assertion5"
        exit 1
    fi
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    cd "$REPO_ROOT"
    
    # Setup phase
    cleanup_test_results
    setup_test_data
    setup_logs
    create_run_dir
    
    # Start containers
    start_containers
    
    # Wait for daemon readiness
    if ! wait_for_daemon; then
        echo "Daemon readiness check failed - proceeding to artifact collection"
        collect_artifacts
        exit 1
    fi
    
    # Debug emacsclient connectivity
    debug_emacsclient
    
    # Cron/emacsclient verification
    if ! verify_cron_emacsclient; then
        echo "WARNING: emacsclient verification failed - continuing anyway"
    fi
    
    # Process inbox
    upload_inbox
    verify_inbox_upload
    diagnose_inbox_file
    
    echo "Saving container view of inbox-mobile.org..."
    podman-compose exec emacs cat /data/inbox-mobile.org > "$RUN_DIR/container-inbox-mobile.org" 2>/dev/null || echo "Could not save container inbox"
    
    trigger_inbox_processing
    
    # Wait for processing to complete
    echo "Waiting 5 seconds for inbox processing to complete..."
    sleep 5
    
    # Write processing results diagnostic
    echo "Writing post-processing diagnostic..."
    podman-compose exec emacs emacsclient -s sem-server --eval '
(with-temp-buffer
  (require (quote org-element))
  (insert "=== PROCESSING DIAGNOSTIC ===\n")
  (insert (format "Time: %s\n" (current-time-string)))
  (insert (format "inbox-mobile.org exists: %s\n" (file-exists-p "/data/inbox-mobile.org")))
  (insert (format "tasks.org exists: %s\n" (file-exists-p "/data/tasks.org")))
  (when (file-exists-p "/data/tasks.org")
    (insert-file-contents "/data/tasks.org")
    (insert (format "Tasks file size: %d bytes\n" (point-max)))
    (insert (format "Tasks content (first 500 chars):\n%s\n"
            (buffer-substring-no-properties (point-min) (min (point-max) 500)))))
  (when (file-exists-p "/data/inbox-mobile.org")
    (insert "\n--- Inbox still exists, content (first 200 chars): ---\n")
    (insert-file-contents "/data/inbox-mobile.org")
    (insert (format "\n%s\n" (buffer-substring-no-properties (point-min) (min (point-max) 200)))))
  (condition-case err
      (progn
        (when (file-exists-p "/data/tasks.org")
          (org-mode)
          (let ((ast (org-element-parse-buffer)))
            (let ((headlines (org-element-map ast (quote headline) (lambda (h) t))))
              (insert (format "Headline count in tasks.org: %d\n" (length headlines)))))))
    (error (insert (format "PARSE ERROR on tasks.org: %s\n" err))))
  (write-region (point-min) (point-max) "/data/sem-proc-diag.txt" nil (quote silent)))
' 2>/dev/null || echo "WARNING: emacsclient processing diagnostic failed"

    # Fetch processing diagnostic
    curl --silent --show-error \
        -u "${WEBDAV_USERNAME}:${WEBDAV_PASSWORD}" \
        -o "$RUN_DIR/sem-proc-diag.txt" \
        "${WEBDAV_BASE_URL}/sem-proc-diag.txt" 2>/dev/null || echo "Could not fetch sem-proc-diag.txt"
    echo "Post-processing diagnostic saved to: $RUN_DIR/sem-proc-diag.txt"
    
    # Wait for tasks
    if ! wait_for_tasks "$EXPECTED_TASK_COUNT"; then
        echo "Tasks poll timeout - proceeding to artifact collection"
    fi
    
    # Collect artifacts
    collect_artifacts
    
    # Run assertions
    run_assertions
}

# Run main
main
