# Specification: planner-preexisting-tasks-regression-coverage

## Purpose

Define integration regression coverage requirements for pre-existing task immutability and overlap-aware planning.

## ADDED Requirements

### Requirement: Integration fixture includes pre-existing tasks shape
The integration workflow MUST load a pre-existing `tasks.org` fixture via the same WebDAV-style path used by test execution. The fixture MUST include at least 5 TODO entries, at least 3 scheduled entries occupying common daytime windows, at least 1 unscheduled entry, at least 1 priority entry, and mixed tags including `work`, `routine`, and at least one additional allowed tag.

#### Scenario: Fixture loaded through WebDAV-style path
- **WHEN** integration setup prepares planner inputs
- **THEN** pre-existing `tasks.org` MUST be loaded through the workflow's WebDAV-style fixture path

#### Scenario: Fixture shape satisfies minimum coverage
- **WHEN** integration assertions validate fixture preconditions
- **THEN** TODO count, scheduled count, unscheduled presence, priority presence, and mixed tag requirements MUST all be satisfied

### Requirement: Integration assertions protect pre-existing TODO immutability
Integration assertions MUST verify that pre-existing TODO entries are not mutated, removed, reordered, or re-timestamped after a full planner run, except for expected append of newly generated tasks.

#### Scenario: Scheduled pre-existing TODOs remain byte-stable
- **WHEN** a full planner run completes
- **THEN** every pre-existing scheduled TODO timestamp MUST exactly match its original value
- **AND** pre-existing entry ordering MUST remain unchanged

#### Scenario: Unscheduled pre-existing TODOs remain unscheduled
- **WHEN** a full planner run completes
- **THEN** every pre-existing TODO with no original `SCHEDULED` field MUST remain unscheduled

### Requirement: Integration assertions verify occupied-window awareness
Integration assertions MUST verify that newly generated tasks respect pre-existing occupied windows by default, and allow overlap only for explicit exception policy conditions.

#### Scenario: Default collision avoidance is enforced
- **WHEN** integration checks newly generated scheduled tasks against pre-existing occupied windows
- **THEN** overlaps MUST be treated as failures unless an explicit exception applies

#### Scenario: Failure diagnostics identify violating task
- **WHEN** any immutability or overlap invariant fails
- **THEN** assertion output MUST include task-level diagnostics identifying the offending task and violated invariant
