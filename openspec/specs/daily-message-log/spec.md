## Purpose

TBD

## Requirements

### Requirement: Write messages to daily log file
`sem-core--flush-messages-daily` SHALL write the `*Messages*` buffer to `/var/log/sem/messages-YYYY-MM-DD.log` where `YYYY-MM-DD` is today's date in container-local UTC time. The date format SHALL be consistent with existing `format-time-string` usage in the codebase. Persisted runtime message lines SHALL be metadata-only and MUST NOT contain raw headline titles, headline bodies, or URLs.

#### Scenario: Messages written to dated log file
- **WHEN** `sem-core--flush-messages-daily` is called
- **AND** today's date is 2026-03-17
- **THEN** messages are appended to `/var/log/sem/messages-2026-03-17.log`

#### Scenario: Date format uses UTC
- **WHEN** the function formats the date
- **THEN** it uses UTC time (consistent with existing time formatting)

#### Scenario: Append mode preserves existing content
- **WHEN** writing to an existing daily log file
- **THEN** new messages are appended (not overwritten)

#### Scenario: Persisted entries exclude plaintext task and link content
- **WHEN** runtime message output is flushed to the daily log
- **THEN** each persisted line contains only operational metadata and opaque identifiers
- **AND** no line contains raw task title text, task body text, or URL strings from inbox items

### Requirement: Function installed on post-command-hook
The `sem-core--flush-messages-daily` function SHALL be installed on `post-command-hook` in place of the old `sem-core--flush-messages` function.

#### Scenario: Hook installation references new function
- **WHEN** `sem-init--install-messages-hook` runs
- **THEN** it adds `sem-core--flush-messages-daily` to `post-command-hook`
- **AND** it does NOT reference the old `sem-core--flush-messages`
