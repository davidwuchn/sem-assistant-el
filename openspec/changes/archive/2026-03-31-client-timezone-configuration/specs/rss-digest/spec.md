## MODIFIED Requirements

### Requirement: rss-digest runs daily at 9:30 AM
The system SHALL generate RSS digests daily at 9:30 AM via cron schedule `30 9 * * *` interpreted in `CLIENT_TIMEZONE`. The digest SHALL fetch and process entries from the Elfeed database from the last 24 hours via LLM and write output to `/data/morning-read/YYYY-MM-DD.org` (general) and `/data/morning-read/YYYY-MM-DD-arxiv.org` (arXiv), where `YYYY-MM-DD` is derived from the client-timezone calendar day at generation time. The function `sem-rss--generate-file` SHALL use `sem-llm-request` instead of direct `gptel-request` calls.

#### Scenario: Scheduled digest generation in client timezone
- **WHEN** cron triggers at 9:30 AM in `CLIENT_TIMEZONE`
- **THEN** `emacsclient -e "(sem-rss-generate-morning-digest)"` is executed

#### Scenario: Digest file date uses client calendar day
- **WHEN** digest output path is generated
- **THEN** the `YYYY-MM-DD` filename date is computed from current day in `CLIENT_TIMEZONE`
- **AND** day rollover follows `CLIENT_TIMEZONE`, not UTC-forced semantics

#### Scenario: sem-llm-request used for LLM call
- **WHEN** `sem-rss--generate-file` generates the digest
- **THEN** it calls `sem-llm-request` (not `gptel-request`)
