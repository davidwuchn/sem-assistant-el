# Specification: planner-overlap-exception-policy

## Purpose

Define overlap policy requirements for Pass 2 scheduling with explicit exceptions.

## ADDED Requirements

### Requirement: Default no-overlap scheduling with explicit exceptions
Pass 2 scheduling MUST avoid overlaps with pre-existing occupied windows by default. Overlap with pre-existing occupied windows MUST be allowed only for explicit exceptions: preserving pre-existing scheduled tasks exactly as authored, or scheduling a high-priority task when no compliant non-overlap slot satisfies runtime constraints.

#### Scenario: Non-priority new task avoids occupied windows
- **WHEN** Pass 2 schedules a newly generated task that is not high priority
- **THEN** the selected timestamp MUST NOT overlap any pre-existing occupied window

#### Scenario: Pre-existing scheduled task is preserved exactly
- **WHEN** Pass 2 processes a pre-existing TODO that already has a SCHEDULED timestamp
- **THEN** the final timestamp MUST exactly match the original timestamp
- **AND** Pass 2 MUST NOT shift, rewrite, or normalize that timestamp

#### Scenario: High-priority exception permits overlap
- **WHEN** Pass 2 processes a high-priority newly generated task and no valid non-overlap slot satisfies runtime constraints
- **THEN** Pass 2 MAY assign an overlapping timestamp
- **AND** Pass 2 MUST still preserve all pre-existing scheduled timestamps unchanged

### Requirement: Exception policy applies generically, not by title
The planner MUST apply overlap exception policy using task state and priority signals, not hardcoded task titles.

#### Scenario: No title-based preservation logic
- **WHEN** Pass 2 evaluates whether a task schedule is immutable
- **THEN** the decision MUST be based on whether the task is pre-existing and scheduled
- **AND** task title text MUST NOT be used as the preservation discriminator
