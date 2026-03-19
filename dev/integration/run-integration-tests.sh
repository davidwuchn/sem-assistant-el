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
        
        if podman exec sem-emacs emacsclient -e "(t)" 2>/dev/null | grep -q "t"; then
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
}

trigger_inbox_processing() {
    echo ""
    echo "=== Triggering Inbox Processing ==="
    
    echo "Calling sem-core-process-inbox..."
    podman exec sem-emacs emacsclient -e "(sem-core-process-inbox)"
    
    echo "Inbox processing triggered"
}

wait_for_tasks() {
    echo ""
    echo "=== Waiting for Tasks.org ==="
    
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
            "${WEBDAV_BASE_URL}/tasks.org" 2>/dev/null; then
            
            # Count TODO entries
            todo_count=$(grep -c '^\* TODO ' "$temp_file" 2>/dev/null || echo "0")
            echo "Found $todo_count TODO entries"
            
            if [[ "$todo_count" -ge 3 ]]; then
                echo "All 3 tasks detected!"
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
            "${WEBDAV_BASE_URL}/tasks.org" 2>/dev/null || touch "$RUN_DIR/tasks.org"
    fi
    
    # GET sem-log.org
    echo "Fetching sem-log.org..."
    curl --silent --show-error \
        -u "${WEBDAV_USERNAME}:${WEBDAV_PASSWORD}" \
        -o "$RUN_DIR/sem-log.org" \
        "${WEBDAV_BASE_URL}/sem-log.org" 2>/dev/null || touch "$RUN_DIR/sem-log.org"
    
    # GET errors.org (may 404 - handle silently)
    echo "Fetching errors.org (may not exist)..."
    if ! curl --fail --silent --show-error \
        -u "${WEBDAV_USERNAME}:${WEBDAV_PASSWORD}" \
        -o "$RUN_DIR/errors.org" \
        "${WEBDAV_BASE_URL}/errors.org" 2>/dev/null; then
        echo "errors.org not found (this is OK)"
        touch "$RUN_DIR/errors.org"
    fi
    
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
    podman logs sem-emacs > "$RUN_DIR/emacs-container.log" 2>&1 || true
    podman logs sem-webdav > "$RUN_DIR/webdav-container.log" 2>&1 || true
    
    echo "Artifacts collected to: $RUN_DIR"
}

# =============================================================================
# Assertions
# =============================================================================

run_assertions() {
    echo ""
    echo "=== Running Assertions ==="
    
    local validation_file="$RUN_DIR/validation.txt"
    local all_passed=true
    
    # Assertion 1: TODO count
    echo "Assertion 1: TODO count..."
    {
        echo "=== Assertion 1: TODO Count ==="
        local todo_count
        todo_count=$(grep -c '^\* TODO ' "$RUN_DIR/tasks.org" 2>/dev/null || echo "0")
        echo "Found $todo_count TODO entries (expected: 3)"
        
        if [[ "$todo_count" -ne 3 ]]; then
            echo "FAIL: expected 3 TODO entries, got $todo_count"
            all_passed=false
        else
            echo "PASS: TODO count is 3"
        fi
        echo ""
    } | tee -a "$validation_file"
    
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
                all_passed=false
            fi
        done
        
        if [[ "$keyword_failed" != "true" ]]; then
            echo "PASS: All keywords present"
        fi
        echo ""
    } | tee -a "$validation_file"
    
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
        else
            echo "FAIL: tasks.org is not valid Org"
            all_passed=false
        fi
        echo ""
    } | tee -a "$validation_file"
    
    # Final result
    {
        echo "=== Final Result ==="
        if [[ "$all_passed" == "true" && "$TEST_STATUS" == "PASS" ]]; then
            echo "ALL ASSERTIONS PASSED"
            exit 0
        else
            echo "SOME ASSERTIONS FAILED"
            exit 1
        fi
    } | tee -a "$validation_file"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    cd "$REPO_ROOT"
    
    # Setup phase
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
    
    # Process inbox
    upload_inbox
    trigger_inbox_processing
    
    # Wait for tasks
    if ! wait_for_tasks; then
        echo "Tasks poll timeout - proceeding to artifact collection"
    fi
    
    # Collect artifacts
    collect_artifacts
    
    # Run assertions
    run_assertions
}

# Run main
main
