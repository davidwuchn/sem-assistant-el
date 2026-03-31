## MODIFIED Requirements

### Requirement: sem-core-log-error appends to errors.org
The `sem-core-log-error` function SHALL call `sem-core-log` with `STATUS=FAIL` or `STATUS=DLQ` AND append the raw error detail to `/data/errors.org` as an actionable Org TODO entry.

#### Scenario: Error logged to sem-log.org
- **WHEN** `sem-core-log-error` is called
- **THEN** an entry with `STATUS=FAIL` or `STATUS=DLQ` is written to `/data/sem-log.org`

#### Scenario: Error detail appended to errors.org
- **WHEN** `sem-core-log-error` is called
- **THEN** the raw error detail is appended to `/data/errors.org`

### Requirement: sem-core-log never raises errors
The `sem-core-log` function SHALL never raise an error itself. The function body SHALL be wrapped in `(cl-block sem-core-log ...)` to support `cl-return-from` calls. All file I/O SHALL be wrapped in `condition-case`. If writing to `/data/sem-log.org` fails, the function SHALL emit a stderr-visible fallback line via `(message "SEM-STDERR: ...")` and continue without crashing.

#### Scenario: Unwritable log file handled
- **WHEN** `/data/sem-log.org` is not writable
- **THEN** `sem-core-log` emits a `SEM-STDERR` fallback message and does not crash

#### Scenario: cl-return-from works correctly
- **WHEN** `sem-core-log` needs to return early due to unwritable log file
- **THEN** `(cl-return-from sem-core-log nil)` executes without error because the function body is wrapped in `cl-block`

#### Scenario: condition-case does not swallow cl-return-from errors
- **WHEN** the `condition-case` handler `(t nil)` is evaluated
- **THEN** it does not attempt to call `t` as a function because `cl-return-from` properly exits the `cl-block` instead of throwing

#### Scenario: Fallback path never raises secondary logging errors
- **WHEN** primary log file I/O fails and fallback emission is attempted
- **THEN** fallback handling does not propagate errors to callers

### Requirement: errors.org format
The `/data/errors.org` file SHALL use the following exact format for each error entry:

```
* TODO [YYYY-MM-DD HH:MM:SS] [MODULE] [EVENT-TYPE] FAIL
DEADLINE: <YYYY-MM-DD Day HH:MM>
:PROPERTIES:
:CREATED: [YYYY-MM-DD HH:MM:SS]
:END:
Error: <error message string>

** Input
<original input text or URL that caused the failure>

** Raw LLM Output
<raw LLM response, or "N/A" if LLM was not called>
```

#### Scenario: Error entry created with actionable scheduling metadata
- **WHEN** an error is logged
- **THEN** a `TODO` headline is created with both `DEADLINE` and `:CREATED:` metadata

#### Scenario: Input preserved
- **WHEN** an error is logged
- **THEN** the original input is saved under `** Input`

#### Scenario: Raw LLM output preserved
- **WHEN** an error is logged
- **THEN** the raw LLM response is saved under `** Raw LLM Output`

#### Scenario: Orgzly sees new errors as overdue actionable items
- **WHEN** a new error is written to `/data/errors.org`
- **THEN** Org clients recognize it as a TODO with an already-due deadline
