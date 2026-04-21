## Purpose

This capability defines the inbox processing pipeline that reads headlines from inbox-mobile.org, routes them through the LLM or URL capture, writes Pass 1 task output to a batch temp file, and then merges final output into tasks.org via planner.

## Requirements

### Requirement: Inbox processing runs every 30 minutes
The system SHALL execute inbox processing every 30 minutes via cron evaluated in `CLIENT_TIMEZONE`. Each run SHALL route task headlines through Pass 1 into `/tmp/data/tasks-tmp-{batch-id}.org` and then invoke conflict-aware Pass 2 planning before append to `/data/tasks.org`. If append preconditions fail due to concurrent file updates, planner outcomes SHALL be retry or explicit non-success, never silent overwrite.

#### Scenario: Scheduled inbox processing executes with conflict-aware append
- **WHEN** the cron schedule triggers at 30-minute intervals in `CLIENT_TIMEZONE`
- **THEN** `sem-core-process-inbox` runs and processes unprocessed headlines
- **AND** final append uses conflict-aware planner checks before writing to `/data/tasks.org`

### Requirement: Pass 1 runtime context uses client timezone semantics
Pass 1 runtime datetime context supplied to the task LLM SHALL be represented in `CLIENT_TIMEZONE`. Prompt wording and formatting MUST NOT imply UTC semantics when `CLIENT_TIMEZONE` is non-UTC.

#### Scenario: Prompt runtime datetime uses configured timezone
- **WHEN** Pass 1 prompt context is generated
- **THEN** runtime datetime values are expressed in `CLIENT_TIMEZONE`

#### Scenario: Prompt wording avoids false UTC implication
- **WHEN** `CLIENT_TIMEZONE` is not UTC
- **THEN** prompt labels and text do not describe runtime context as UTC

#### Scenario: Unprocessed headlines are processed
- **WHEN** `/data/inbox-mobile.org` contains headlines not yet in the cursor file
- **THEN** each unprocessed headline is sent through the LLM pipeline

#### Scenario: Pass 1 output is written to batch temp file
- **WHEN** the LLM returns valid structured Org output for a task headline
- **THEN** the output is appended to `/tmp/data/tasks-tmp-{batch-id}.org`

#### Scenario: Contention produces explicit planner outcome
- **WHEN** concurrent updates change `tasks.org` during planner merge window
- **THEN** planner records retry or non-success outcome
- **AND** no silent last-writer-wins overwrite occurs

### Requirement: inbox-mobile.org is read-only except during 4AM purge window
The system SHALL NOT write to `/data/inbox-mobile.org` at any time except during the 4:00 AM daily purge window. LLM output SHALL NEVER be written back to `inbox-mobile.org`.

#### Scenario: Regular processing does not modify inbox
- **WHEN** inbox processing runs at any time other than 4:00 AM
- **THEN** `/data/inbox-mobile.org` is opened read-only and not modified

#### Scenario: LLM output never goes back to inbox-mobile.org
- **WHEN** the LLM pipeline produces structured task output
- **THEN** output is written to the batch temp file and later merged into `/data/tasks.org`, never to `inbox-mobile.org`

### Requirement: Processed node identity tracked via content hashes
The system SHALL track processed headlines using `/data/.sem-cursor.el` containing content hashes. A headline SHALL be marked as processed only after successful output is written. The hash input format SHALL be a structured JSON array encoding of title, space-joined tags, and body, computed as `(secure-hash 'sha256 (json-encode (vector title tags-str body)))`.

#### Scenario: Hash recorded after successful processing
- **WHEN** a headline is successfully processed and output is written
- **THEN** the headline's content hash is added to `.sem-cursor.el`

#### Scenario: Already-processed headlines are skipped
- **WHEN** inbox processing encounters a headline whose hash exists in `.sem-cursor.el`
- **THEN** the headline is skipped without calling the LLM

#### Scenario: Hash input uses unambiguous structured encoding
- **WHEN** computing a content hash for cursor identity
- **THEN** the hash input is `(json-encode (vector title tags-str body))` instead of delimiter-joined strings

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

### Requirement: Malformed LLM output sent to Dead Letter Queue
The system SHALL detect malformed LLM output (non-valid Org structure). Malformed output SHALL be written to `/data/errors.org` (Dead Letter Queue) and the node SHALL be marked as processed to prevent infinite retry loops.

#### Scenario: Malformed output detected and logged
- **WHEN** the LLM returns output missing `:PROPERTIES:`, `:ID:`, or `#+title:`
- **THEN** the raw response and original input are appended to `/data/errors.org`

#### Scenario: Malformed output node marked processed
- **WHEN** malformed output is sent to the Dead Letter Queue
- **THEN** the node hash is added to `.sem-cursor.el` to prevent infinite retry

### Requirement: :link: tagged headlines routed to url-capture
The system SHALL detect headlines tagged with `:link:`. These headlines SHALL be routed to `sem-url-capture-process` instead of the task LLM pipeline. The URL SHALL be extracted from the bare headline title text.

#### Scenario: :link: headline routed to url-capture
- **WHEN** a headline has the tag `:link:` (e.g. `* https://example.com :link:`)
- **THEN** `sem-router.el` calls `sem-url-capture-process` with the URL

#### Scenario: URL extracted from headline title
- **WHEN** processing a `:link:` headline
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

### Requirement: :task: tagged headlines routed to task LLM pipeline
The system SHALL detect headlines tagged with `:task:`. These headlines SHALL be routed to `sem-router--route-to-task-llm` for LLM processing instead of being silently discarded. The routing SHALL occur after checking for `:link:` tags and deterministic `:journal:` routing.

#### Scenario: :task: headline routed to task LLM
- **WHEN** a headline has the tag `:task:` (e.g. `* Task description :task:`)
- **THEN** `sem-router.el` calls `sem-router--route-to-task-llm` with the headline content

#### Scenario: :task: headline not silently discarded
- **WHEN** a `:task:` headline is processed
- **THEN** the headline is sent to the LLM, not marked processed without LLM call

#### Scenario: Journal route evaluated before task route
- **WHEN** inbox processing evaluates deterministic routing tags
- **THEN** `:journal:` routing is handled before falling through to `:task:` handling

### Requirement: tasks.org created on first write if absent
The system SHALL create `/data/tasks.org` if it does not exist when the first processed output needs to be written.

#### Scenario: tasks.org auto-created
- **WHEN** the first headline is successfully processed and `/data/tasks.org` does not exist
- **THEN** the file is created and the output is written

### Requirement: Headlines parsed with org-element including body
The function `sem-router--parse-headlines` SHALL use `org-element-parse-buffer` and `org-element-map` over `headline` type elements instead of regex. It SHALL return the same plist shape as before plus a `:body` key. Tags SHALL be extracted via `org-element-property :tags`. Title SHALL be extracted via `org-element-property :raw-value`. Body SHALL be extracted as the concatenated text of all non-headline child elements of the headline, trimmed. Debug logging in this parse path SHALL use numeric position values only and SHALL NOT call numeric operators with marker objects.

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
- **THEN** the formula is `(secure-hash 'sha256 (json-encode (vector title (or tags-str "") (or body ""))))`

#### Scenario: Debug preview bounds use numeric positions
- **WHEN** `sem-router--parse-headlines` emits debug preview logging
- **THEN** numeric bound expressions use numeric positions (for example `(min (point-max) 100)`)
- **AND** marker objects are not passed to numeric operators such as `min`

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
- **THEN** it explains that concurrent client/server edits can still conflict despite atomic file replacement

### Requirement: sem-core--batch-id incremented at start of each cron-triggered inbox processing
At the start of each cron-triggered `sem-core-process-inbox`, `sem-core--batch-id` SHALL be incremented.

#### Scenario: Batch ID increments on new cron run
- **WHEN** `sem-core-process-inbox` is called by cron
- **THEN** `sem-core--batch-id` is incremented

### Requirement: sem-core--pending-callbacks tracks routed items
`sem-core--pending-callbacks` SHALL be tracked for each routed inbox item. The counter SHALL be incremented when a callback is registered and decremented when it completes.

#### Scenario: Pending count tracked per item
- **WHEN** an inbox item is routed to LLM
- **THEN** `sem-core--pending-callbacks` is incremented

### Requirement: Pass 1 results written to batch temp file
During inbox processing, Pass 1 results SHALL be written to the batch temp file `/tmp/data/tasks-tmp-{batch-id}.org` instead of tasks.org.

#### Scenario: Results written to temp file
- **WHEN** Pass 1 generates task entries
- **THEN** they are written to `/tmp/data/tasks-tmp-{batch-id}.org`

### Requirement: Planning step called when pending count reaches zero
`sem-planner-run-planning-step` SHALL be called when `sem-core--pending-callbacks` reaches 0.

#### Scenario: Planning step called at barrier
- **WHEN** the last pending callback completes
- **THEN** `sem-planner-run-planning-step` is invoked

### Requirement: rules.org read at start of each batch
`rules.org` SHALL be read fresh at the start of each `sem-core-process-inbox` call via `sem-rules-read`.

#### Scenario: Rules read at batch start
- **WHEN** `sem-core-process-inbox` starts
- **THEN** `sem-rules-read` is called to get current rules

### Requirement: Inbox routing diagnostics avoid plaintext content
Runtime `message` diagnostics emitted during inbox parsing, routing, callback completion, barrier coordination, retry signaling, and stale-callback handling SHALL contain only operational metadata and opaque identifiers. These diagnostics MUST NOT include raw headline titles, headline body snippets, or URL strings.

#### Scenario: Parse and route diagnostics are metadata-only
- **WHEN** inbox processing emits parse or route progress messages
- **THEN** each message contains only metadata fields (for example counts, statuses, batch ID, hash prefix)
- **AND** raw title/body/URL plaintext is not present

#### Scenario: Callback and barrier diagnostics are metadata-only
- **WHEN** async callback completion or batch barrier diagnostics are emitted
- **THEN** each message remains uniquely traceable using metadata identifiers
- **AND** raw title/body/URL plaintext is not present

#### Scenario: Validation failure diagnostics are metadata-only
- **WHEN** an item fails validation and the runtime emits failure diagnostics
- **THEN** emitted messages include status and opaque identifiers only
- **AND** no raw headline/body snippets are present in the message text
