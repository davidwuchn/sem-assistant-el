## ADDED Requirements

### Requirement: rss-digest runs daily at 9:30 AM
The system SHALL generate RSS digests daily at 9:30 AM via cron schedule `30 9 * * *`. The digest SHALL fetch and process entries from the Elfeed database from the last 24 hours via LLM and write output to `/data/morning-read/YYYY-MM-DD.org` (general) and `/data/morning-read/YYYY-MM-DD-arxiv.org` (arXiv).

#### Scenario: Scheduled digest generation
- **WHEN** the cron triggers at 9:30 AM
- **THEN** `emacsclient -e "(sem-rss-generate-morning-digest)"` is executed

#### Scenario: General digest written
- **WHEN** there are general feed entries in the last 24 hours
- **THEN** a digest file is written to `/data/morning-read/YYYY-MM-DD.org`

#### Scenario: arXiv digest written
- **WHEN** there are arXiv feed entries in the last 24 hours
- **THEN** a digest file is written to `/data/morning-read/YYYY-MM-DD-arxiv.org`

### Requirement: rss-digest reads local Elfeed DB only
The system SHALL read from the local Elfeed database only. The `rss-digest` capability SHALL NOT call `elfeed-update` itself — it relies on the 5-8AM update runs to populate the database.

#### Scenario: No elfeed-update called during digest
- **WHEN** `sem-rss-generate-morning-digest` is executing
- **THEN** no `elfeed-update` call is made

### Requirement: Lookback window is exactly 24 hours
The system SHALL use a fixed 24-hour lookback window for entry collection. This is not configurable interactively.

#### Scenario: 24-hour lookback applied
- **WHEN** collecting entries for digest
- **THEN** only entries from the last 24 hours are included

### Requirement: Per-feed entry cap and token limits via env vars
The system SHALL respect `RSS_MAX_ENTRIES_PER_FEED` and `RSS_MAX_INPUT_CHARS` environment variables for limiting entries per feed and total input size. Defaults SHALL apply if unset.

#### Scenario: Entry cap applied
- **WHEN** `RSS_MAX_ENTRIES_PER_FEED` is set
- **THEN** no more than that many entries per feed are included

#### Scenario: Token limit applied
- **WHEN** `RSS_MAX_INPUT_CHARS` is set
- **THEN** total input to LLM is truncated to that limit

#### Scenario: Defaults used when unset
- **WHEN** environment variables are not set
- **THEN** default values (10 entries, 199000 chars) are applied

### Requirement: No file written if no entries found
The system SHALL NOT write a digest file if no entries are found for a filter. No LLM call SHALL be made in this case.

#### Scenario: No entries, no file
- **WHEN** no entries match the general filter in the last 24 hours
- **THEN** no general digest file is written

#### Scenario: No arXiv entries, no file
- **WHEN** no entries match the arXiv filter in the last 24 hours
- **THEN** no arXiv digest file is written

#### Scenario: No LLM call on empty input
- **WHEN** no entries are found
- **THEN** no LLM request is made
