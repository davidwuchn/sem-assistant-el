## ADDED Requirements

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

### Requirement: post-command-hook flushes messages
The system SHALL add `sem-core--flush-messages` to `post-command-hook`. This hook SHALL append `*Messages*` buffer content to `/var/log/sem/messages.log` after every `emacsclient` invocation.

#### Scenario: Messages flushed after each command
- **WHEN** an `emacsclient` command completes
- **THEN** `sem-core--flush-messages` is called via `post-command-hook`

#### Scenario: Append mode used
- **WHEN** `sem-core--flush-messages` writes to the log file
- **THEN** it appends (does not overwrite) using `write-region` with `t` argument

### Requirement: messages.log not rotated by daemon
The system SHALL NOT rotate `messages.log`. Log rotation SHALL be the operator's responsibility (e.g., `logrotate` on the host).

#### Scenario: No automatic rotation
- **WHEN** `messages.log` grows large
- **THEN** the daemon does not rotate or truncate it automatically

### Requirement: logs directory must exist before docker-compose up
The operator SHALL create the `./logs/` directory on the host before running `docker-compose up`. Docker-compose does not create host-side bind mount directories on all platforms.

#### Scenario: Deployment docs include mkdir step
- **WHEN** operator follows deployment instructions
- **THEN** `mkdir -p logs` is run before first `docker-compose up`

### Requirement: sem-core--flush-messages wrapped in condition-case
The `sem-core--flush-messages` function SHALL be wrapped in `condition-case`. It SHALL never crash the daemon if `/var/log/sem/` is unwritable.

#### Scenario: Unwritable log directory handled
- **WHEN** `/var/log/sem/` is not writable
- **THEN** `sem-core--flush-messages` catches the error and does not crash the daemon
