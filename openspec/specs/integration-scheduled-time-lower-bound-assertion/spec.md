# Specification: integration-scheduled-time-lower-bound-assertion

## Purpose

Define requirements for integration assertions that enforce strict scheduled-time lower bounds.

## ADDED Requirements

### Requirement: Integration validates minimum scheduled start time
The integration workflow SHALL validate that each generated scheduled task starts strictly after
`runtime_now + 1 hour` for the current test run.

#### Scenario: Non-exception task satisfies strict lower bound
- **WHEN** a generated task has a `SCHEDULED` timestamp and does not match the fixed-schedule exception title after normalization
- **THEN** the parsed timestamp MUST be strictly greater than the run lower bound
- **AND** equality with the lower bound MUST be treated as failure

#### Scenario: Lower-bound violation fails with diagnostic context
- **WHEN** a generated task timestamp is less than or equal to the run lower bound
- **THEN** the assertion MUST fail
- **AND** the failure message MUST include task title, actual timestamp, and lower-bound timestamp

### Requirement: Integration preserves explicit fixed-schedule exception
The integration workflow SHALL enforce fixture-consistent schedule matching for the task titled
`Process quarterly financial reports`.

#### Scenario: Exception task matches fixture timestamp exactly
- **WHEN** validating `Process quarterly financial reports`
- **THEN** the generated scheduled timestamp MUST match the timestamp intent defined in
  `dev/integration/testing-resources/inbox-tasks.org`

#### Scenario: Date-only fixture timestamp matches same-day ranged output
- **WHEN** the fixed-schedule exception fixture uses date-only form `<YYYY-MM-DD Day>`
- **THEN** assertion matching MUST accept generated timestamps on the same UTC calendar day
- **AND** lower-bound and overlap checks MUST remain skipped for the matched exception task

#### Scenario: Exception title matching tolerates normalization artifacts
- **WHEN** matching generated task titles to `Process quarterly financial reports` for assertion branching
- **THEN** comparison MUST be case-insensitive
- **AND** Org priority markers (for example `[#C]`) MUST be ignored
- **AND** comparison MAY use a bounded partial-title match to tolerate deterministic title normalization

### Requirement: Datetime comparison uses one timezone authority
All timestamp comparisons SHALL normalize parsed datetimes into a single runtime timezone
authority before ordering or equality checks.

#### Scenario: Comparable values are normalized before checks
- **WHEN** evaluating lower-bound or exact-match assertions
- **THEN** runtime and scheduled datetimes MUST be normalized into the same timezone context
- **AND** string-only datetime comparison MUST NOT be used
