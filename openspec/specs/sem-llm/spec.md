## Purpose

This capability defines the LLM wrapper module that provides a consistent interface for all LLM calls with error handling and retry logic.

## Requirements

### Requirement: sem-llm wraps gptel-request
The system SHALL provide `sem-llm.el` as a wrapper around `gptel-request`. All LLM calls from `sem-router.el`, `sem-rss.el`, and `sem-url-capture.el` SHALL go through `sem-llm.el`.

#### Scenario: LLM call via sem-llm
- **WHEN** a module needs to call the LLM
- **THEN** it calls a function in `sem-llm.el`

#### Scenario: Direct gptel-request forbidden
- **WHEN** a module is implemented
- **THEN** it does not call `gptel-request` directly

### Requirement: condition-case wrapper for all callbacks
The `sem-llm` module SHALL wrap all LLM callbacks in `condition-case`. Errors in callbacks SHALL be caught and logged via `sem-core-log`.

#### Scenario: Callback errors caught
- **WHEN** an LLM callback raises an error
- **THEN** the error is caught and logged, not propagated

### Requirement: Retry vs DLQ decision enforced
The `sem-llm` module SHALL enforce the retry-vs-DLQ decision:
- API error (429, timeout): do NOT mark processed, retry on next run
- Malformed output (invalid Org): mark processed and send to DLQ

#### Scenario: API error triggers retry
- **WHEN** the LLM API returns an error (429, timeout)
- **THEN** the node hash is NOT added to the cursor; it will retry

#### Scenario: Malformed output triggers DLQ
- **WHEN** the LLM returns malformed output (not valid Org)
- **THEN** the node hash IS added to the cursor and output goes to DLQ

### Requirement: sem-llm calls sem-core-log on success/failure
The `sem-llm` module SHALL call `sem-core-log` on both success and failure of LLM requests.

#### Scenario: Success logged
- **WHEN** an LLM request completes successfully
- **THEN** `sem-core-log` is called with `STATUS=OK`

#### Scenario: Failure logged
- **WHEN** an LLM request fails
- **THEN** `sem-core-log` is called with `STATUS=FAIL` or `STATUS=RETRY`
