## Purpose

Define bounded API-failure retry behavior and terminal DLQ routing for task LLM processing while preserving distinct malformed-output handling semantics.

## Requirements

### Requirement: Task API failures use bounded retry state
Task LLM API-failure handling SHALL increment retry state exactly once per failed attempt and SHALL stop retry attempts when the configured retry cap is reached.

#### Scenario: API failure below retry cap increments state and retries
- **WHEN** a task LLM request fails due to API/provider error and current retry count is below the configured cap
- **THEN** the system increments retry state for that task by one
- **AND** the task remains eligible for another retry attempt

#### Scenario: API failure at retry cap does not schedule further retries
- **WHEN** a task LLM request fails due to API/provider error and retry count reaches the configured cap
- **THEN** no additional retry attempt is scheduled for that task

### Requirement: Terminal API failures are routed to DLQ
When task LLM API-failure retries are exhausted, the task SHALL be routed to DLQ as a terminal failure outcome.

#### Scenario: Exhausted API retries create terminal DLQ outcome
- **WHEN** a task LLM request continues failing until the configured retry cap is exhausted
- **THEN** the task is moved to DLQ
- **AND** task status is recorded as terminal failure for API-failure handling

### Requirement: Malformed-output handling remains distinct from API-failure handling
Malformed LLM output handling and malformed task input detected during preflight-sensitive sanitization MUST remain separate paths from API-failure handling and MUST be treated as terminal security failures. Malformed-sensitive preflight failures MUST NOT increment API-failure retry state and MUST NOT trigger retry scheduling.

#### Scenario: Malformed output does not increment API-failure retry state
- **WHEN** the LLM call succeeds but returns malformed output
- **THEN** the system handles the result through malformed-output logic
- **AND** API-failure retry state is not incremented for that event

#### Scenario: Malformed-sensitive preflight does not increment API retry state
- **WHEN** task preflight-sensitive sanitization fails with malformed delimiters
- **THEN** API-failure retry state is unchanged

#### Scenario: Malformed-sensitive preflight routes directly to DLQ
- **WHEN** task preflight-sensitive sanitization fails with malformed delimiters
- **THEN** the task is routed to DLQ terminal handling without retry

#### Scenario: Transient provider failures still use bounded retries
- **WHEN** a task LLM request fails due to provider/API error after successful preflight
- **THEN** bounded API-failure retry behavior remains in effect
