## MODIFIED Requirements

### Requirement: Assertions validate test outcomes
The system SHALL run assertions after artifact collection to validate integration test results. All configured assertions MUST run even when some fail, and assertion coverage MUST include pre-existing TODO immutability and occupied-window overlap policy checks.

#### Scenario: All assertions run regardless of prior failures
- **WHEN** running assertions
- **THEN** all configured assertions MUST run even if one fails
- **AND** short-circuiting MUST NOT occur

#### Scenario: TODO count assertion
- **WHEN** running the TODO count assertion
- **THEN** `grep -c '^\* TODO ' tasks.org` MUST equal EXPECTED_TASK_COUNT
- **AND** if it fails, the message MUST be `FAIL: expected N TODO entries, got M` (where `N=EXPECTED_TASK_COUNT`)

#### Scenario: Keyword presence assertion
- **WHEN** running the keyword presence assertion
- **THEN** the script MUST grep for each headline title keyword defined in the `keywords` array in `tasks.org`
- **AND** each configured keyword MUST match
- **AND** if any keyword is missing, the failure message MUST name the missing keyword

#### Scenario: Scheduled time lower-bound and overlap policy assertion
- **WHEN** running scheduling policy assertions
- **THEN** each newly generated scheduled task MUST be strictly greater than `runtime_now + 1 hour`
- **AND** newly generated tasks MUST avoid overlaps with pre-existing occupied windows by default
- **AND** overlaps with pre-existing occupied windows MUST be accepted only for explicit exception policy cases
- **AND** if a violation occurs, the failure message MUST identify the task and compared timestamps or conflicting window

#### Scenario: Pre-existing TODO immutability assertion
- **WHEN** running pre-existing lifecycle assertions after a full run
- **THEN** pre-existing TODO entries MUST NOT be mutated, removed, reordered, or re-timestamped
- **AND** pre-existing TODOs without original `SCHEDULED` MUST remain unscheduled
- **AND** expected append-only addition of newly generated tasks MUST be allowed

#### Scenario: Org validity assertion
- **WHEN** running the Org validity assertion
- **THEN** the script MUST run:
  ```
  emacs --batch \
    --eval "(condition-case err \
              (progn (find-file \"RUN_DIR/tasks.org\") \
                     (org-mode) \
                     (org-element-parse-buffer) \
                     (message \"ORG-VALID\")) \
            (error (error \"ORG-INVALID: %s\" err)))"
  ```
- **AND** exit code 0 indicates valid
- **AND** non-zero indicates invalid with message `FAIL: tasks.org is not valid Org`

#### Scenario: Sensitive content restoration assertion
- **WHEN** running the sensitive content restoration assertion
- **THEN** the script MUST grep for each sensitive keyword defined in the `sensitive_keywords` array in `tasks.org`
- **AND** each keyword MUST be present in the output (proving sensitive content was unmasked)
- **AND** if any keyword is missing, the failure message MUST name the missing keyword

#### Scenario: Final exit code reflects assertion results
- **WHEN** all assertions have completed
- **THEN** the script MUST exit with code 0 if all assertions passed
- **AND** exit with code 1 if any assertion failed
