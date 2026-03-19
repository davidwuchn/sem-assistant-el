## ADDED Requirements

### Requirement: Assertions validate test outcomes
The system SHALL run assertions after artifact collection to validate the integration test results.

#### Scenario: All assertions run regardless of prior failures
- **WHEN** running assertions
- **THEN** all 3 assertions MUST run even if one fails
- **AND** short-circuiting MUST NOT occur

#### Scenario: TODO count assertion
- **WHEN** running the TODO count assertion
- **THEN** `grep -c '^\* TODO ' tasks.org` MUST equal 3
- **AND** if it fails, the message MUST be "FAIL: expected 3 TODO entries, got N"

#### Scenario: Keyword presence assertion
- **WHEN** running the keyword presence assertion
- **THEN** the script MUST grep for each of the 3 headline title keywords in tasks.org
- **AND** each keyword MUST match
- **AND** if any keyword is missing, the failure message MUST name the missing keyword

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
- **AND** non-zero indicates invalid with message "FAIL: tasks.org is not valid Org"

#### Scenario: Final exit code reflects assertion results
- **WHEN** all assertions have completed
- **THEN** the script MUST exit with code 0 if all assertions passed
- **AND** exit with code 1 if any assertion failed