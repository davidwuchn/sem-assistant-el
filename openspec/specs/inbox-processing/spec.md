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
The system SHALL handle the case where `/data/inbox-mobile.org` does not exist when the cron job fires. The daemon SHALL log a warning and exit cleanly without creating the file. The function `sem-router--parse-headlines` SHALL be wrapped in `(cl-block sem-router--parse-headlines ...)` to support `cl-return-from` usage without crashing.

#### Scenario: Missing inbox file logs warning
- **WHEN** the cron job fires and `/data/inbox-mobile.org` does not exist
- **THEN** a warning is logged to `/data/sem-log.org` and the function exits cleanly

#### Scenario: Daemon does not create inbox-mobile.org
- **WHEN** `/data/inbox-mobile.org` is absent
- **THEN** the daemon does not create it; Orgzly is the sole creator

#### Scenario: cl-return-from does not crash
- **WHEN** `sem-router--parse-headlines` executes with `cl-return-from` statements
- **THEN** no crash occurs due to missing `cl-block` wrapper

### Requirement: @task tagged headlines routed to task LLM pipeline
The system SHALL detect headlines tagged with `@task`. These headlines SHALL be routed to `sem-router--route-to-task-llm` for LLM processing instead of being silently discarded. The routing SHALL occur in `sem-router--route-headline` after checking for `@link` tags.

#### Scenario: @task headline routed to task LLM
- **WHEN** a headline has the tag `@task` (e.g. `* Task description :@task:`)
- **THEN** `sem-router.el` calls `sem-router--route-to-task-llm` with the headline content

#### Scenario: @task headline not silently discarded
- **WHEN** an `@task` headline is processed
- **THEN** the headline is sent to the LLM, not marked processed without LLM call

### Requirement: tasks.org created on first write if absent
The system SHALL create `/data/tasks.org` if it does not exist when the first processed output needs to be written.

#### Scenario: tasks.org auto-created
- **WHEN** the first headline is successfully processed and `/data/tasks.org` does not exist
- **THEN** the file is created and the output is written

### Requirement: Headlines parsed with org-element including body
The function `sem-router--parse-headlines` SHALL use `org-element-parse-buffer` and `org-element-map` over `headline` type elements instead of regex. It SHALL return the same plist shape as before plus a `:body` key. Tags SHALL be extracted via `org-element-property :tags`. Title SHALL be extracted via `org-element-property :raw-value`. Body SHALL be extracted as the concatenated text of all non-headline child elements of the headline, trimmed.

#### Scenario: Headline parsed with org-element
- **WHEN** `sem-router--parse-headlines` processes an Org buffer
- **THEN** it uses `org-element-parse-buffer` to get the AST
- **AND** it uses `org-element-map` with type `'headline` to iterate

#### Scenario: Plist includes body key
- **WHEN** `sem-router--parse-headlines` returns headline plists
- **THEN** each plist contains `:title`, `:tags`, `:body`, `:point`, and `:hash` keys

#### Scenario: Tags extracted without colons
- **WHEN** parsing a headline with tags `:tag1:tag2:`
- **THEN** the `:tags` value is a list of strings `("tag1" "tag2")` without colons

#### Scenario: Hash includes body in computation
- **WHEN** computing the hash for a headline
- **THEN** the formula is `(secure-hash 'sha256 (concat title "|" (or tags-str "") "|" (or body "")))`

### Requirement: README documents Orgzly sync timing warning
The README SHALL contain a **WARNING** section immediately after the "Scheduled Tasks" table titled "Orgzly Sync Timing". The section SHALL warn users that Orgzly must not sync during specific windows to prevent data loss.

#### Scenario: Warning section present in README
- **WHEN** viewing the README after the "Scheduled Tasks" table
- **THEN** a "WARNING: Orgzly Sync Timing" section is present

#### Scenario: Warning specifies unsafe windows
- **WHEN** reading the Orgzly Sync Timing warning
- **THEN** it specifies windows `XX:28–XX:32` and `XX:58–XX:02` (every hour)
- **AND** it specifies window `04:00–04:05` (purge window)

#### Scenario: Warning explains reason
- **WHEN** reading the Orgzly Sync Timing warning
- **THEN** it explains that concurrent writes cause silent data loss due to non-atomic read-modify-write operations
