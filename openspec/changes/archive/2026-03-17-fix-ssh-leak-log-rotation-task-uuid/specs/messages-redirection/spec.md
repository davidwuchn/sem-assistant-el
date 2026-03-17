## MODIFIED Requirements

### Requirement: Messages flushed to daily log file
The system SHALL add `sem-core--flush-messages-daily` to `post-command-hook`. This hook SHALL append `*Messages*` buffer content to `/var/log/sem/messages-YYYY-MM-DD.log` after every `emacsclient` invocation, where `YYYY-MM-DD` is the current UTC date. On date rollover, the buffer SHALL be erased before writing to ensure the new day's file starts clean.

#### Scenario: Messages flushed to daily file after each command
- **WHEN** an `emacsclient` command completes
- **THEN** `sem-core--flush-messages-daily` is called via `post-command-hook`
- **AND** messages are appended to `/var/log/sem/messages-YYYY-MM-DD.log`

#### Scenario: Date rollover triggers buffer erase
- **WHEN** the current date differs from `sem-core--last-flush-date`
- **THEN** the `*Messages*` buffer is erased BEFORE writing
- **AND** messages are written to the new day's file
- **AND** `sem-core--last-flush-date` is updated

#### Scenario: Same day continues appending
- **WHEN** the current date equals `sem-core--last-flush-date`
- **THEN** the `*Messages*` buffer is NOT erased
- **AND** messages continue appending to the same file

#### Scenario: Append mode used
- **WHEN** `sem-core--flush-messages-daily` writes to the log file
- **THEN** it appends (does not overwrite) using `write-region` with `t` argument

### Requirement: messages.log not rotated by daemon
The system SHALL NOT rotate individual daily log files. Each day's file grows until the next day begins, at which point a new file is created. Log rotation on the host SHALL remain the operator's responsibility (e.g., `logrotate` on the host).

#### Scenario: No automatic rotation within a day
- **WHEN** `messages-2026-03-17.log` grows large
- **THEN** the daemon continues appending to the same file until date changes

#### Scenario: New file on date change
- **WHEN** the date changes from 2026-03-17 to 2026-03-18
- **THEN** subsequent messages are written to `messages-2026-03-18.log`

### Requirement: sem-core--flush-messages-daily wrapped in condition-case
The `sem-core--flush-messages-daily` function SHALL be wrapped in `condition-case`. It SHALL never crash the daemon if `/var/log/sem/` is unwritable.

#### Scenario: Unwritable log directory handled
- **WHEN** `/var/log/sem/` is not writable
- **THEN** `sem-core--flush-messages-daily` catches the error and does not crash the daemon

## REMOVED Requirements

### Requirement: post-command-hook flushes messages to single file
**Reason**: Replaced by daily log file rotation for better log management and O(N²) growth prevention.
**Migration**: Use `sem-core--flush-messages-daily` which writes to dated files instead of `messages.log`.

### Requirement: messages.log not rotated by daemon (old single-file version)
**Reason**: The old single-file `messages.log` is replaced by daily files. This requirement is superseded by the new daily rotation behavior.
**Migration**: Log files are now automatically split by date; use `logrotate` on the host for archiving old daily files if needed.
