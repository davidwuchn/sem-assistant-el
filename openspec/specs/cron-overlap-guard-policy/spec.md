# Specification: cron-overlap-guard-policy

## Purpose

Define non-overlap guard policy for cron-triggered SEM jobs.

## ADDED Requirements

### Requirement: Cron-triggered jobs enforce single active execution per guard key
The system SHALL enforce a non-overlap guard for cron-triggered SEM jobs so that only one active execution per guard key can run at a time. A second trigger that arrives while a guarded execution is active SHALL NOT start a concurrent duplicate for the same guard key.

#### Scenario: Overlapping trigger for same guard key is suppressed
- **WHEN** a cron trigger starts a guarded job and the same guarded job is triggered again before completion
- **THEN** the second trigger does not start a concurrent duplicate execution

#### Scenario: Different guard keys can run independently
- **WHEN** two cron triggers target different guard keys
- **THEN** both jobs are allowed to execute without blocking each other

### Requirement: Overlap outcome is deterministic and restart-safe
The system SHALL define a deterministic overlap outcome for guarded jobs. For each guard key, overlap behavior SHALL be explicitly configured as skip or serialize, and the selected behavior SHALL be consistent across daemon restarts.

#### Scenario: Skip policy yields deterministic no-op for overlap
- **WHEN** a guarded job uses skip policy and an overlapping trigger occurs
- **THEN** the overlapping trigger is recorded as skipped and no duplicate run is started

#### Scenario: Serialize policy yields deterministic deferred execution
- **WHEN** a guarded job uses serialize policy and an overlapping trigger occurs
- **THEN** the overlapping trigger is queued or deferred and executes only after the active run completes

### Requirement: Stale lock and crash recovery are handled safely
The system SHALL detect stale lock artifacts and recover from crashed holders without permitting duplicate active execution. Lock age checks SHALL use a deterministic stale threshold and SHALL tolerate clock skew by failing closed when lock freshness cannot be trusted.

#### Scenario: Stale lock is reclaimed
- **WHEN** a lock artifact is older than the configured stale threshold and no active holder exists
- **THEN** the system reclaims the stale lock and allows exactly one new execution to proceed

#### Scenario: Uncertain lock age fails closed
- **WHEN** lock age cannot be evaluated reliably due to clock skew or invalid timestamps
- **THEN** the system treats the lock as active and suppresses new overlapping execution for that guard key

### Requirement: Guard decisions are observable in operational logs
The system SHALL emit explicit operational logs for guard decisions, including lock acquisition, overlap skip or serialize decisions, stale lock recovery, and recovery failures.

#### Scenario: Overlap decision is logged
- **WHEN** a trigger is skipped or deferred due to an active guard
- **THEN** an operational log entry records the guard key, decision type, and reason

#### Scenario: Stale lock recovery is logged
- **WHEN** stale lock recovery is attempted
- **THEN** an operational log entry records whether recovery succeeded or failed
