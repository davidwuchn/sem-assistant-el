## ADDED Requirements

### Requirement: Pass 2 planning uses optimistic concurrency against tasks.org
The planner SHALL compute a base content hash from `tasks.org` before building Pass 2 input and SHALL verify that hash again immediately before appending merged output. The append MUST proceed only when the base hash still matches.

#### Scenario: Base hash unchanged allows append
- **WHEN** Pass 2 planning completes and the pre-append hash matches the planning base hash
- **THEN** the planner appends merged output to `tasks.org`

#### Scenario: Base hash mismatch blocks stale append
- **WHEN** the pre-append hash differs from the planning base hash
- **THEN** the planner MUST reject the stale append attempt

### Requirement: Planner re-runs Pass 2 on conflict with bounded retries
On hash mismatch, the planner SHALL rebuild Pass 2 context from the latest `tasks.org` state and rerun Pass 2 planning under a bounded retry limit.

#### Scenario: Replan uses refreshed file state
- **WHEN** a conflict is detected before append
- **THEN** the planner reloads the latest `tasks.org` content and reruns Pass 2 planning

#### Scenario: Retry budget exhaustion returns explicit non-success
- **WHEN** conflicts continue until the bounded retry limit is exhausted
- **THEN** the planner returns an explicit non-success outcome and MUST NOT append stale content

### Requirement: Conflict outcomes are logged deterministically
Conflict detection, each retry attempt, and final non-success outcomes SHALL be logged with deterministic status values suitable for audit and debugging.

#### Scenario: Conflict path emits deterministic log sequence
- **WHEN** a stale-write conflict and retry occur
- **THEN** logs include conflict detection, retry attempt count, and final success or non-success outcome
