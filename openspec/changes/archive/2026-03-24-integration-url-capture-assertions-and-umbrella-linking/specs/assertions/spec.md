# Specification: assertions

## MODIFIED Requirements

### Requirement: Assertions validate test outcomes
The system SHALL run assertions after artifact collection to validate integration test results. All configured assertions MUST run even when some fail, and assertion coverage MUST include pre-existing TODO immutability checks, occupied-window overlap policy checks, and trusted URL-capture output checks.

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
- **AND** each keyword MUST match
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
- **THEN** the script MUST grep for each sensitive keyword defined in the `sensitive_keywords` array in tasks.org
- **AND** each keyword MUST be present in the output (proving sensitive content was unmasked)
- **AND** if any keyword is missing, the failure message MUST name the missing keyword

#### Scenario: URL-capture trusted output assertion
- **WHEN** running trusted URL-capture assertions
- **THEN** at least one new captured org-roam node MUST contain required org-roam headers (`:PROPERTIES:`, `:ID:`, `#+title:`)
- **AND** the same node MUST contain exact trusted URL in `#+ROAM_REFS`
- **AND** the same node MUST contain exact `Source: [[URL][URL]]` in `* Summary`
- **AND** the same node MUST include a link to `[[id:96a58b04-1f58-47c9-993f-551994939252][...]]`
- **AND** defanged URL forms (`hxxp://`, `hxxps://`) MUST NOT appear in validated trusted-URL candidate nodes

#### Scenario: Final exit code reflects assertion results
- **WHEN** all assertions have completed
- **THEN** the script MUST exit with code 0 if all assertions passed
- **AND** exit with code 1 if any assertion failed, including URL-capture assertion failures
