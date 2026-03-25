## MODIFIED Requirements

### Requirement: LLM API errors trigger retry on next run
The system SHALL NOT mark a node as processed when the LLM API returns an error (429 rate limit, timeout). The system SHALL also NOT mark a `:link:` node as processed when URL capture fails due to timeout. These nodes SHALL be retried on the next cron run under existing retry controls.

#### Scenario: Rate limit error does not mark processed
- **WHEN** the LLM API returns HTTP 429 (rate limit exceeded)
- **THEN** the node hash is NOT added to `.sem-cursor.el`

#### Scenario: Timeout error does not mark processed
- **WHEN** the LLM API request times out
- **THEN** the node hash is NOT added to `.sem-cursor.el` and retries next run

#### Scenario: URL-capture timeout does not mark link processed
- **WHEN** `sem-url-capture-process` reaches timeout for a `:link:` headline
- **THEN** the headline hash is NOT added to `.sem-cursor.el`
- **AND** the headline remains eligible for retry on subsequent runs
