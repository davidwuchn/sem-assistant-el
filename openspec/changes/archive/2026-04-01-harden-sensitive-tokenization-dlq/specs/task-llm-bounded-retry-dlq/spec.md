## MODIFIED Requirements

### Requirement: Malformed-output handling remains distinct from API-failure handling
Malformed task input detected during preflight-sensitive sanitization MUST remain distinct from API-failure handling and MUST be treated as a terminal security failure. Malformed-sensitive preflight failures MUST NOT increment API-failure retry state and MUST NOT trigger retry scheduling.

#### Scenario: Malformed-sensitive preflight does not increment API retry state
- **WHEN** task preflight-sensitive sanitization fails with malformed delimiters
- **THEN** API-failure retry state is unchanged

#### Scenario: Malformed-sensitive preflight routes directly to DLQ
- **WHEN** task preflight-sensitive sanitization fails with malformed delimiters
- **THEN** the task is routed to DLQ terminal handling without retry

#### Scenario: Transient provider failures still use bounded retries
- **WHEN** a task LLM request fails due to provider/API error after successful preflight
- **THEN** bounded API-failure retry behavior remains in effect
