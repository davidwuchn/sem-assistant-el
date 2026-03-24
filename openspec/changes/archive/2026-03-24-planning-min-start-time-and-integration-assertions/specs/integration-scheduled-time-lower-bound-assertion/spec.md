## ADDED Requirements

### Requirement: Integration validates minimum scheduled start time
The integration workflow SHALL validate that each generated scheduled task starts strictly after
`runtime_now + 1 hour` for the current test run.

#### Scenario: Non-exception task satisfies strict lower bound
- **WHEN** a generated task has a `SCHEDULED` timestamp and title is not `Process quarterly financial reports`
- **THEN** the parsed timestamp MUST be strictly greater than the run lower bound
- **AND** equality with the lower bound MUST be treated as failure

#### Scenario: Lower-bound violation fails with diagnostic context
- **WHEN** a generated task timestamp is less than or equal to the run lower bound
- **THEN** the assertion MUST fail
- **AND** the failure message MUST include task title, actual timestamp, and lower-bound timestamp

### Requirement: Integration preserves explicit fixed-schedule exception
The integration workflow SHALL enforce an exact timestamp match for the task titled
`Process quarterly financial reports`.

#### Scenario: Exception task matches fixture timestamp exactly
- **WHEN** validating `Process quarterly financial reports`
- **THEN** the generated scheduled timestamp MUST equal the timestamp defined in
  `dev/integration/testing-resources/inbox-tasks.org`

### Requirement: Datetime comparison uses one timezone authority
All timestamp comparisons SHALL normalize parsed datetimes into a single runtime timezone
authority before ordering or equality checks.

#### Scenario: Comparable values are normalized before checks
- **WHEN** evaluating lower-bound or exact-match assertions
- **THEN** runtime and scheduled datetimes MUST be normalized into the same timezone context
- **AND** string-only datetime comparison MUST NOT be used
