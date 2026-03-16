## Purpose

This capability defines the inbox processing pipeline that reads headlines from inbox-mobile.org, routes them through the LLM or URL capture, and writes structured output to tasks.org or org-roam nodes.

## Requirements

### Requirement: Inbox processing runs every 30 minutes
The system SHALL execute inbox processing every 30 minutes via cron. Each run SHALL read unprocessed headlines from `/data/inbox-mobile.org`, pass them through the LLM, and write structured output to `/data/tasks.org`.

#### Scenario: Scheduled inbox processing executes
- **WHEN** the cron schedule triggers at 30-minute intervals
- **THEN** `sem-core-process-inbox` is called via `emacsclient`

#### Scenario: Unprocessed headlines are processed
- **WHEN** `/data/inbox-mobile.org` contains headlines not yet in the cursor file
- **THEN** each unprocessed headline is sent through the LLM pipeline

#### Scenario: Processed output is written to tasks.org
- **WHEN** the LLM returns valid structured Org output
- **THEN** the output is appended to `/data/tasks.org`

### Requirement: inbox-mobile.org is read-only except during 4AM purge window
The system SHALL NOT write to `/data/inbox-mobile.org` at any time except during the 4:00 AM daily purge window. LLM output SHALL NEVER be written back to `inbox-mobile.org`.

#### Scenario: Regular processing does not modify inbox
- **WHEN** inbox processing runs at any time other than 4:00 AM
- **THEN** `/data/inbox-mobile.org` is opened read-only and not modified

#### Scenario: LLM output goes to tasks.org only
- **WHEN** the LLM pipeline produces structured task output
- **THEN** output is written to `/data/tasks.org`, not to `inbox-mobile.org`

### Requirement: Processed node identity tracked via content hashes
The system SHALL track processed headlines using `/data/.sem-cursor.el` containing content hashes. A headline SHALL be marked as processed only after successful output is written.

#### Scenario: Hash recorded after successful processing
- **WHEN** a headline is successfully processed and output is written
- **THEN** the headline's content hash is added to `.sem-cursor.el`

#### Scenario: Already-processed headlines are skipped
- **WHEN** inbox processing encounters a headline whose hash exists in `.sem-cursor.el`
- **THEN** the headline is skipped without calling the LLM

### Requirement: LLM API errors trigger retry on next run
The system SHALL NOT mark a node as processed when the LLM API returns an error (429 rate limit, timeout). The node SHALL be retried on the next cron run.

#### Scenario: Rate limit error does not mark processed
- **WHEN** the LLM API returns HTTP 429 (rate limit exceeded)
- **THEN** the node hash is NOT added to `.sem-cursor.el`

#### Scenario: Timeout error does not mark processed
- **WHEN** the LLM API request times out
- **THEN** the node hash is NOT added to `.sem-cursor.el` and retries next run

### Requirement: Malformed LLM output sent to Dead Letter Queue
The system SHALL detect malformed LLM output (non-valid Org structure). Malformed output SHALL be written to `/data/errors.org` (Dead Letter Queue) and the node SHALL be marked as processed to prevent infinite retry loops.

#### Scenario: Malformed output detected and logged
- **WHEN** the LLM returns output missing `:PROPERTIES:`, `:ID:`, or `#+title:`
- **THEN** the raw response and original input are appended to `/data/errors.org`

#### Scenario: Malformed output node marked processed
- **WHEN** malformed output is sent to the Dead Letter Queue
- **THEN** the node hash is added to `.sem-cursor.el` to prevent infinite retry

### Requirement: @link tagged headlines routed to url-capture
The system SHALL detect headlines tagged with `@link`. These headlines SHALL be routed to `sem-url-capture-process` instead of the task LLM pipeline. The URL SHALL be extracted from the bare headline title text.

#### Scenario: @link headline routed to url-capture
- **WHEN** a headline has the tag `@link` (e.g. `* https://example.com :@link:`)
- **THEN** `sem-router.el` calls `sem-url-capture-process` with the URL

#### Scenario: URL extracted from headline title
- **WHEN** processing an `@link` headline
- **THEN** the URL is extracted directly from the headline title string

### Requirement: inbox-mobile.org non-existence handled gracefully
The system SHALL handle the case where `/data/inbox-mobile.org` does not exist when the cron job fires. The daemon SHALL log a warning and exit cleanly without creating the file.

#### Scenario: Missing inbox file logs warning
- **WHEN** the cron job fires and `/data/inbox-mobile.org` does not exist
- **THEN** a warning is logged to `/data/sem-log.org` and the function exits cleanly

#### Scenario: Daemon does not create inbox-mobile.org
- **WHEN** `/data/inbox-mobile.org` is absent
- **THEN** the daemon does not create it; Orgzly is the sole creator

### Requirement: tasks.org created on first write if absent
The system SHALL create `/data/tasks.org` if it does not exist when the first processed output needs to be written.

#### Scenario: tasks.org auto-created
- **WHEN** the first headline is successfully processed and `/data/tasks.org` does not exist
- **THEN** the file is created and the output is written
