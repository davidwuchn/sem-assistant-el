## Purpose

Define privacy-safe daemon runtime diagnostics that preserve operability and traceability without exposing plaintext inbox content.

## Requirements

### Requirement: Runtime message output is metadata-only
All daemon runtime `message` output that can be persisted by `sem-core--flush-messages-daily` SHALL exclude raw user-provided or externally sourced plaintext, including headline titles, headline bodies, and URLs. Runtime messages SHALL use only operational metadata fields such as module, action, status, counts, batch IDs, and short opaque identifiers.

#### Scenario: Task routing success emits metadata only
- **WHEN** inbox routing emits a success `message` for a processed task item
- **THEN** the message includes only metadata fields
- **AND** the message does not include the task title text, body text, or source URL

#### Scenario: Failure path emits metadata only
- **WHEN** inbox parsing, routing, or callback handling emits an error-status `message`
- **THEN** the message includes only metadata fields and opaque identifiers
- **AND** no raw headline/body/URL plaintext is emitted

### Requirement: Metadata-only format remains deterministic across retries
For the same routed item and batch context, metadata-only `message` fields SHALL remain stable across retry and watchdog-driven flows so operators can correlate events without exposing content.

#### Scenario: Retry event correlation uses opaque identifiers
- **WHEN** a routed item is retried after an LLM or URL-capture failure
- **THEN** emitted messages use the same correlation identifiers (for example batch ID plus hash prefix)
- **AND** emitted messages do not include plaintext title, body, or URL fields

#### Scenario: Stale callback diagnostics remain traceable without plaintext
- **WHEN** a stale callback is detected and a diagnostic `message` is emitted
- **THEN** the message includes sufficient metadata to identify the stale callback path
- **AND** the message excludes raw title/body/URL content
