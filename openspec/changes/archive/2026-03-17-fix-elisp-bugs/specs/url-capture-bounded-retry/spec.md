## ADDED Requirements

### Requirement: URL capture failures retry up to 3 times
The system SHALL implement bounded retry for URL capture failures. When `sem-url-capture-process` returns `nil` (indicating trafilatura or LLM failure), the router SHALL increment a retry counter for that headline. After 3 cumulative failures, the headline SHALL be moved to DLQ. Before 3 failures, the headline SHALL remain unprocessed for retry on the next cron cycle.

#### Scenario: First failure increments retry counter
- **WHEN** `sem-url-capture-process` returns `nil` for a headline
- **THEN** the retry counter for that headline hash is incremented to 1
- **AND** the headline is NOT marked as processed

#### Scenario: Second failure increments retry counter
- **WHEN** `sem-url-capture-process` returns `nil` for a headline with retry count 1
- **THEN** the retry counter is incremented to 2
- **AND** the headline is NOT marked as processed

#### Scenario: Third failure moves to DLQ
- **WHEN** `sem-url-capture-process` returns `nil` for a headline with retry count 2
- **THEN** the headline is moved to DLQ via `sem-core--mark-dlq`
- **AND** the headline is marked as processed
- **AND** the retry counter is cleared

#### Scenario: Success clears retry counter
- **WHEN** `sem-url-capture-process` returns a filepath for a headline with retry count > 0
- **THEN** the retry counter is cleared
- **AND** the headline is marked as processed

### Requirement: Retry counter uses headline content hash
The system SHALL use the headline content hash as the retry counter key. The key format SHALL match the existing `@task` retry key format.

#### Scenario: Same headline content same key
- **WHEN** two headlines have identical content
- **THEN** they share the same retry counter key

#### Scenario: Different headline content different key
- **WHEN** two headlines have different content
- **THEN** they have different retry counter keys

### Requirement: DLQ escalation writes to errors.org and logs
The system SHALL write DLQ-escalated headlines to `/data/errors.org` and log to `sem-log.org` with status DLQ when a URL capture reaches 3 failures.

#### Scenario: DLQ write on third failure
- **WHEN** a headline reaches 3 URL capture failures
- **THEN** the headline is appended to `/data/errors.org`
- **AND** an entry is written to `sem-log.org` with status DLQ

### Requirement: Processing markers moved to callback
The system SHALL call `sem-router--mark-processed` only inside the `sem-url-capture-process` callback, not at the dispatch site. The callback SHALL mark processed on success (filepath non-nil) or on DLQ escalation (3rd failure).

#### Scenario: Processing marked on success
- **WHEN** `sem-url-capture-process` callback receives a filepath
- **THEN** `sem-router--mark-processed` is called
- **AND** `processed-count` is incremented

#### Scenario: Processing marked on DLQ
- **WHEN** `sem-url-capture-process` callback handles a 3rd failure
- **THEN** `sem-core--mark-dlq` is called
- **AND** `sem-router--mark-processed` is called

#### Scenario: Processing NOT marked on retryable failure
- **WHEN** `sem-url-capture-process` callback handles a 1st or 2nd failure
- **THEN** `sem-router--mark-processed` is NOT called
- **AND** the headline remains for next cron cycle

## MODIFIED Requirements

### Requirement: Headline marked processed after url-capture invoked
**Previous behavior:** The headline was marked as processed regardless of success or failure, preventing any retry.

**New behavior:** The headline is only marked as processed on success or after 3 failures (DLQ). Retryable failures (1st and 2nd) leave the headline unprocessed for the next cron cycle.

#### Scenario: Failure NOT marked processed (retryable)
- **WHEN** `sem-url-capture-process` returns `nil` and retry count < 3
- **THEN** the headline hash is NOT added to `.sem-cursor.el`
- **AND** the headline will be retried on next cron run

#### Scenario: Failure marked processed (DLQ)
- **WHEN** `sem-url-capture-process` returns `nil` and retry count reaches 3
- **THEN** the headline hash IS added to `.sem-cursor.el`
- **AND** the headline is moved to `/data/errors.org`
