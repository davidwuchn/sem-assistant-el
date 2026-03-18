## Purpose

This capability defines the RSS digest generation system that creates morning digests from Elfeed entries.

## Requirements

### Requirement: rss-digest runs daily at 9:30 AM
The system SHALL generate RSS digests daily at 9:30 AM via cron schedule `30 9 * * *`. The digest SHALL fetch and process entries from the Elfeed database from the last 24 hours via LLM and write output to `/data/morning-read/YYYY-MM-DD.org` (general) and `/data/morning-read/YYYY-MM-DD-arxiv.org` (arXiv). The function `sem-rss--generate-file` SHALL use `sem-llm-request` instead of direct `gptel-request` calls.

#### Scenario: Scheduled digest generation
- **WHEN** the cron triggers at 9:30 AM
- **THEN** `emacsclient -e "(sem-rss-generate-morning-digest)"` is executed

#### Scenario: sem-llm-request used for LLM call
- **WHEN** `sem-rss--generate-file` generates the digest
- **THEN** it calls `sem-llm-request` (not `gptel-request`)

### Requirement: No file written if no entries found
The system SHALL NOT write a digest file if no entries are found for a filter. No LLM call SHALL be made in this case. On malformed LLM output, the error SHALL be logged to `errors.org` and the output file SHALL NOT be written. On API error, the error SHALL be logged to `errors.org` with RETRY status and the output file SHALL NOT be written.

#### Scenario: No entries, no file
- **WHEN** no entries match the general filter in the last 24 hours
- **THEN** no general digest file is written

#### Scenario: Malformed output logged to errors.org
- **WHEN** the LLM returns malformed output for rss-digest
- **THEN** the error is logged to `/data/errors.org` and no output file is written

#### Scenario: API error logged with RETRY status
- **WHEN** the LLM API returns an error during rss-digest generation
- **THEN** the error is logged to `/data/errors.org` with RETRY status and no output file is written

### Requirement: sem-llm-request handles nil hash for rss-digest
The function `sem-rss--generate-file` SHALL pass `nil` as the `hash` argument to `sem-llm-request` because RSS digest has no per-entry cursor deduplication. The functions `sem-llm-request` and its helpers (e.g., `sem-core--mark-processed`) SHALL handle `nil` hash without crashing.

#### Scenario: nil hash passed to sem-llm-request
- **WHEN** `sem-rss--generate-file` calls `sem-llm-request`
- **THEN** it passes `nil` as the `hash` argument

#### Scenario: nil hash handled gracefully
- **WHEN** `sem-llm-request` receives `nil` hash
- **THEN** it completes without crashing

#### Scenario: sem-core--mark-processed no-op on nil
- **WHEN** `sem-core--mark-processed` is called with `nil`
- **THEN** it is a no-op (does not crash, does not modify cursor)

### Requirement: RSS prompt builders use template variables
The functions `sem-rss--build-general-prompt` and `sem-rss--build-arxiv-prompt` SHALL replace inline `format` string literals with `format` using the loaded template variables `sem-rss-general-prompt-template` and `sem-rss-arxiv-prompt-template`. The argument order and types SHALL remain unchanged: general prompt uses (days, category-list, days, entries-text); arXiv prompt uses (category-list, days, entries-text).

#### Scenario: General prompt uses template variable
- **WHEN** `sem-rss--build-general-prompt` is called
- **THEN** it calls `(format sem-rss-general-prompt-template days category-list days entries-text)`
- **AND** it does not use a hardcoded string literal

#### Scenario: arXiv prompt uses template variable
- **WHEN** `sem-rss--build-arxiv-prompt` is called
- **THEN** it calls `(format sem-rss-arxiv-prompt-template category-list days entries-text)`
- **AND** it does not use a hardcoded string literal

#### Scenario: Template variables loaded at startup
- **WHEN** the `sem-rss` module finishes loading
- **THEN** `sem-rss-general-prompt-template` is a non-nil, non-empty string
- **AND** `sem-rss-arxiv-prompt-template` is a non-nil, non-empty string

#### Scenario: Missing template file aborts daemon
- **WHEN** the `sem-rss` module loads and a prompt file is missing or empty
- **THEN** an error is signaled and the daemon aborts startup
