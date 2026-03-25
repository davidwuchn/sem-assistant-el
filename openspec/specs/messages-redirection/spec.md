## Purpose

This capability defines the messages redirection system that persists the Emacs *Messages* buffer to a host-mounted log directory.

## Requirements

### Requirement: *Messages* buffer persisted to host-mounted log directory
The system SHALL persist the Emacs `*Messages*` buffer to a durable host-mounted log directory outside the `/data` volume. This ensures messages survive container crashes and volume replacements.

#### Scenario: Messages flushed to host log
- **WHEN** an `emacsclient` invocation completes
- **THEN** `*Messages*` buffer content is appended to the host-mounted log file

### Requirement: Host mount declared in docker-compose
The docker-compose file SHALL declare a second host mount on the Emacs container: `./logs:/var/log/sem:rw`. The `./logs/` directory SHALL live next to `docker-compose.yml` on the VPS host — outside `/data`.

#### Scenario: Host mount configured
- **WHEN** docker-compose starts the Emacs container
- **THEN** `./logs` on the host is mounted to `/var/log/sem` in the container

#### Scenario: Logs directory outside /data
- **WHEN** inspecting the volume structure
- **THEN** `./logs/` is separate from `/data/`

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

### Requirement: daily message logs not rotated by daemon
The system SHALL NOT rotate individual daily log files. Each day's file grows until the next day begins, at which point a new file is created. Log rotation on the host SHALL remain the operator's responsibility (e.g., `logrotate` on the host).

#### Scenario: No automatic rotation within a day
- **WHEN** `messages-2026-03-17.log` grows large
- **THEN** the daemon continues appending to the same file until date changes

#### Scenario: New file on date change
- **WHEN** the date changes from 2026-03-17 to 2026-03-18
- **THEN** subsequent messages are written to `messages-2026-03-18.log`

### Requirement: logs directory must exist before docker-compose up
The operator SHALL create the `./logs/` directory on the host before running `docker-compose up`. Docker-compose does not create host-side bind mount directories on all platforms.

#### Scenario: Deployment docs include mkdir step
- **WHEN** operator follows deployment instructions
- **THEN** `mkdir -p logs` is run before first `docker-compose up`

### Requirement: sem-core--flush-messages-daily wrapped in condition-case
The `sem-core--flush-messages-daily` function SHALL be wrapped in `condition-case`. It SHALL never crash the daemon if `/var/log/sem/` is unwritable.

#### Scenario: Unwritable log directory handled
- **WHEN** `/var/log/sem/` is not writable
- **THEN** `sem-core--flush-messages-daily` catches the error and does not crash the daemon
