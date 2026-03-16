## Purpose

This capability defines the LLM routing for `sem-url-capture-process`, ensuring all LLM calls go through `sem-llm-request` for proper hash tracking and DLQ logging.

## Requirements

### Requirement: sem-url-capture-process routes LLM calls through sem-llm-request
The `sem-url-capture-process` function SHALL call `sem-llm-request` instead of calling `gptel-request` directly. The `sem-url-capture--validate-and-save` function SHALL be passed as the success callback via the context plist.

#### Scenario: LLM request via sem-llm-request
- **WHEN** `sem-url-capture-process` needs to call the LLM after fetching article content
- **THEN** it calls `sem-llm-request` with the sanitized content and umbrella node context

#### Scenario: Success callback passed via context
- **WHEN** `sem-llm-request` is called
- **THEN** `sem-url-capture--validate-and-save` is passed as the success callback in the context plist

#### Scenario: Function signature unchanged
- **WHEN** `sem-url-capture--validate-and-save` is defined
- **THEN** its function signature remains unchanged from the original implementation

### Requirement: Hash marked processed on malformed LLM response (DLQ path)
When the LLM returns malformed output (invalid Org structure, missing required fields), the system SHALL mark the headline hash as processed in `.sem-cursor.el` and send the output to the DLQ (errors.org).

#### Scenario: Malformed output marks hash processed
- **WHEN** the LLM returns output that fails validation (missing `:PROPERTIES:`, `:ID:`, or `#+title:`)
- **THEN** the headline hash is added to `.sem-cursor.el` to prevent retry

#### Scenario: Malformed output sent to DLQ
- **WHEN** the LLM returns malformed output
- **THEN** the output is logged to `/data/errors.org`

### Requirement: Hash NOT marked processed on API error (retry path)
When the LLM API returns an error (429 rate limit, timeout, connection failure), the system SHALL NOT mark the headline hash as processed, allowing the headline to be retried on the next daemon run.

#### Scenario: API error does not mark hash processed
- **WHEN** the LLM API returns an error (429, timeout, connection failure)
- **THEN** the headline hash is NOT added to `.sem-cursor.el`

#### Scenario: API error logged for retry
- **WHEN** the LLM API returns an error
- **THEN** the error is logged via `sem-core-log` with `STATUS=RETRY`

### Requirement: Fetch step (trafilatura) unchanged
The article fetching step using `trafilatura` SHALL remain unchanged. The `sem-url-capture--fetch-url` function SHALL continue to call `trafilatura` CLI directly and return the extracted content.

#### Scenario: Trafilatura fetch unchanged
- **WHEN** `sem-url-capture-process` is called with a URL
- **THEN** the fetch step calls `trafilatura` CLI as before

#### Scenario: Fetch errors handled as before
- **WHEN** `trafilatura` fails or returns empty content
- **THEN** the error is logged and `nil` is returned, as before
