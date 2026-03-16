## MODIFIED Requirements

### Requirement: sem-core-log never raises errors
The `sem-core-log` function SHALL never raise an error itself. The function body SHALL be wrapped in `(cl-block sem-core-log ...)` to support `cl-return-from` calls. All file I/O SHALL be wrapped in `condition-case` and fall back to `message` if the log file is unwritable.

#### Scenario: Unwritable log file handled
- **WHEN** `/data/sem-log.org` is not writable
- **THEN** `sem-core-log` falls back to `(message)` and does not crash

#### Scenario: cl-return-from works correctly
- **WHEN** `sem-core-log` needs to return early due to unwritable log file
- **THEN** `(cl-return-from sem-core-log nil)` executes without error because the function body is wrapped in `cl-block`

#### Scenario: condition-case does not swallow cl-return-from errors
- **WHEN** the `condition-case` handler `(t nil)` is evaluated
- **THEN** it does not attempt to call `t` as a function because `cl-return-from` properly exits the `cl-block` instead of throwing
