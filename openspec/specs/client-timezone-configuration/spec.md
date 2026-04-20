## Purpose

This capability defines required client timezone configuration and makes it authoritative for runtime time interpretation and scheduling semantics.

## Requirements

### Requirement: Mandatory client timezone configuration
The system SHALL require a `CLIENT_TIMEZONE` configuration value at startup. `CLIENT_TIMEZONE` MUST be a valid IANA timezone identifier available in the runtime environment.

When runtime timezone APIs require tzfile-style rules, the system SHALL resolve
the configured IANA identifier to an equivalent zoneinfo-backed rule
representation without changing the configured `CLIENT_TIMEZONE` value.

#### Scenario: Startup fails when CLIENT_TIMEZONE is missing
- **WHEN** daemon startup begins and `CLIENT_TIMEZONE` is unset or empty
- **THEN** startup fails before cron workflows or inbox processing begin

#### Scenario: Startup fails when CLIENT_TIMEZONE is invalid
- **WHEN** daemon startup begins and `CLIENT_TIMEZONE` does not resolve to a valid IANA timezone
- **THEN** startup fails with an explicit configuration error

#### Scenario: Runtime uses zoneinfo-backed rule for IANA timezone
- **WHEN** `CLIENT_TIMEZONE` is an IANA identifier and matching tzdata is available
- **THEN** runtime time formatting uses an equivalent zoneinfo-backed timezone rule
- **AND** user-visible configuration remains the original IANA value

### Requirement: CLIENT_TIMEZONE is authoritative runtime timezone
The system SHALL treat `CLIENT_TIMEZONE` as the single authoritative timezone for runtime scheduling semantics, timestamp interpretation, and day-boundary logic.

#### Scenario: Runtime time consumers use CLIENT_TIMEZONE
- **WHEN** scheduling, planning, purge-window checks, digest-date derivation, or daily log partitioning evaluate time
- **THEN** they use `CLIENT_TIMEZONE` semantics consistently

#### Scenario: Cron/system runtime context uses CLIENT_TIMEZONE
- **WHEN** cron daemon and shell-level runtime time APIs evaluate current time
- **THEN** they use timezone data derived from `CLIENT_TIMEZONE`
- **AND** they do not fall back to implicit UTC unless `CLIENT_TIMEZONE` is explicitly UTC

#### Scenario: Startup fails when CLIENT_TIMEZONE zoneinfo is missing
- **WHEN** `CLIENT_TIMEZONE` points to an IANA identifier not present in runtime zoneinfo data
- **THEN** daemon startup fails before cron scheduling begins

### Requirement: No per-item timezone override support
The system SHALL NOT support per-user, per-task, or per-entry timezone overrides for scheduling behavior in this change.

#### Scenario: Task metadata cannot override timezone
- **WHEN** a task or headline contains timezone-like metadata
- **THEN** scheduling logic continues using `CLIENT_TIMEZONE` only
