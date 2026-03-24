# Specification: assertions

## Purpose

Define requirements for integration test assertions that validate outcomes.

## ADDED Requirements

### Requirement: Assertions validate test outcomes
The system SHALL run assertions after artifact collection to validate the integration test results.

#### Scenario: All assertions run regardless of prior failures
- **WHEN** running assertions
- **THEN** all 4 assertions MUST run even if one fails
- **AND** short-circuiting MUST NOT occur

#### Scenario: TODO count assertion
- **WHEN** running the TODO count assertion
- **THEN** `grep -c '^\* TODO ' tasks.org` MUST equal EXPECTED_TASK_COUNT
- **AND** if it fails, the message MUST be "FAIL: expected N TODO entries, got M" (where N=EXPECTED_TASK_COUNT)

#### Scenario: Keyword presence assertion
- **WHEN** running the keyword presence assertion
- **THEN** the script MUST grep for each headline title keyword defined in the `keywords` array in tasks.org
- **AND** the `keywords` array MUST include `quarterly financial reports`, `#452`, and `team building activity`
- **AND** each keyword MUST match
- **AND** if any keyword is missing, the failure message MUST name the missing keyword

#### Scenario: Org validity assertion
- **WHEN** running the Org validity assertion
- **THEN** the script MUST run:
  ```
  emacs --batch \
    --eval "(condition-case err \
              (progn (find-file "RUN_DIR/tasks.org") \
                     (org-mode) \
                     (org-element-parse-buffer) \
                     (message "ORG-VALID")) \
            (error (error "ORG-INVALID: %s" err)))"
  ```
- **AND** exit code 0 indicates valid
- **AND** non-zero indicates invalid with message "FAIL: tasks.org is not valid Org"

#### Scenario: Sensitive content restoration assertion
- **WHEN** running the sensitive content restoration assertion
- **THEN** the script MUST grep for each sensitive keyword defined in the `sensitive_keywords` array in tasks.org
- **AND** each keyword MUST be present in the output (proving sensitive content was unmasked)
- **AND** if any keyword is missing, the failure message MUST name the missing keyword

#### Scenario: Final exit code reflects assertion results
- **WHEN** all assertions have completed
- **THEN** the script MUST exit with code 0 if all assertions passed
- **AND** exit with code 1 if any assertion failed
