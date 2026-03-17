## 1. SSH Agent Lifecycle Management

### 1.1 Modify sem-git-sync--setup-ssh for agent reuse
- [x] 1.1.1 Add check for existing SSH_AUTH_SOCK env var and socket file existence
- [x] 1.1.2 Skip ssh-agent -s when valid existing agent detected
- [x] 1.1.3 Return second value indicating reuse vs spawn path
- [x] 1.1.4 Update function documentation

### 1.2 Create sem-git-sync--teardown-ssh function
- [x] 1.2.1 Implement ssh-agent -k call using SSH_AGENT_PID
- [x] 1.2.2 Add guard to only kill agents spawned in current cycle
- [x] 1.2.3 Handle nil SSH_AGENT_PID gracefully

### 1.3 Update sem-git-sync-org-roam with unwind-protect
- [x] 1.3.1 Add sem-git-sync--agent-spawned-this-cycle local variable
- [x] 1.3.2 Wrap git push in unwind-protect with teardown call
- [x] 1.3.3 Ensure teardown runs on success, failure, and condition

## 2. Daily Message Log Rotation

### 2.1 Create sem-core--flush-messages-daily function
- [x] 2.1.1 Implement date-based filename generation (messages-YYYY-MM-DD.log)
- [x] 2.1.2 Add UTC time formatting consistent with existing code
- [x] 2.1.3 Implement append-mode file writing
- [x] 2.1.4 Wrap in condition-case for error handling

### 2.2 Add date rollover detection
- [x] 2.2.1 Define sem-core--last-flush-date module variable (initial "")
- [x] 2.2.2 Compare current date with last-flush-date on each invocation
- [x] 2.2.3 Implement buffer erase before writing on date change
- [x] 2.2.4 Update last-flush-date after successful write

### 2.3 Update init.el hook installation
- [x] 2.3.1 Change sem-init--install-messages-hook to reference sem-core--flush-messages-daily
- [x] 2.3.2 Remove old sem-core--flush-messages references
- [x] 2.3.3 Verify hook installation on daemon startup

## 3. Task UUID Injection and Validation

### 3.1 Modify sem-router--route-to-task-llm for UUID injection
- [x] 3.1.1 Add (org-id-new) call before prompt construction
- [x] 3.1.2 Bind injected-id in let scope
- [x] 3.1.3 Inject :ID: <injected-id> into user prompt template
- [x] 3.1.4 Add system prompt instruction for verbatim ID usage
- [x] 3.1.5 Pass injected-id in context plist as :injected-id

### 3.2 Update sem-router--validate-task-response signature
- [x] 3.2.1 Change signature to (response injected-id)
- [x] 3.2.2 Implement ID extraction using re-search-forward pattern
- [x] 3.2.3 Add string= comparison between extracted and injected ID
- [x] 3.2.4 Return nil on mismatch or missing ID

### 3.3 Update all internal call sites
- [x] 3.3.1 Find all callers of sem-router--validate-task-response in sem-router.el
- [x] 3.3.2 Update each call site to pass injected-id as second parameter
- [x] 3.3.3 Ensure DLQ path is taken on validation failure

## 4. Test Implementation

### 4.1 Extend sem-git-sync-test.el
- [x] 4.1.1 Add test for agent reuse when SSH_AUTH_SOCK valid
- [x] 4.1.2 Add test for new agent spawn when socket missing
- [x] 4.1.3 Add test for teardown after successful push
- [x] 4.1.4 Add test for teardown after failed push
- [x] 4.1.5 Add test for no-kill when agent was reused
- [x] 4.1.6 Add test for unwind-protect ensuring teardown on condition

### 4.2 Extend sem-core-test.el
- [x] 4.2.1 Add test for daily log file naming format
- [x] 4.2.2 Add test for buffer erase on date rollover
- [x] 4.2.3 Add test for no-erase on same-day flush
- [x] 4.2.4 Add test for append mode (not overwrite)
- [x] 4.2.5 Add test for error handling when log directory unwritable

### 4.3 Extend sem-router-test.el
- [x] 4.3.1 Update existing validate-task-response tests for new signature
- [x] 4.3.2 Add test for UUID match → validation passes
- [x] 4.3.3 Add test for UUID mismatch → validation fails
- [x] 4.3.4 Add test for missing ID → validation fails
- [x] 4.3.5 Add test for injected UUID present in prompt string
- [x] 4.3.6 Add test for DLQ path on validation failure

### 4.4 Test Infrastructure
- [x] 4.4.1 Verify all new tests registered in sem-test-runner.el
- [x] 4.4.2 Ensure no network calls in tests (use sem-mock-*)
- [x] 4.4.3 Ensure no filesystem side-effects (use temp files)
- [x] 4.4.4 Run full test suite: emacs --batch --load app/elisp/tests/sem-test-runner.el
- [x] 4.4.5 Verify exit code 0 with zero failures and zero errors

## 5. Verification and Cleanup

### 5.1 Code Review
- [x] 5.1.1 Review all modified functions for correctness
- [x] 5.1.2 Verify no pre-existing agents are killed
- [x] 5.1.3 Verify buffer erase happens BEFORE write on rollover
- [x] 5.1.4 Verify UUID validation uses exact string match

### 5.2 Documentation
- [x] 5.2.1 Update function docstrings for modified functions
- [x] 5.2.2 Add comments for complex logic (unwind-protect, date rollover)
- [x] 5.2.3 Verify no stray references to old function names

### 5.3 Final Verification
- [x] 5.3.1 Run complete test suite one final time
- [x] 5.3.2 Verify all existing tests still pass
- [x] 5.3.3 Verify new tests cover all spec scenarios
- [x] 5.3.4 Confirm implementation matches design decisions
