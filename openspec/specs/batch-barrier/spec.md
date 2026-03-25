## Purpose

This capability defines the count-based barrier that fires the planning step when all callbacks in a batch have completed.

## ADDED Requirements

### Requirement: Pending callbacks counter
The system SHALL maintain `sem-core--pending-callbacks`, a counter that tracks the number of pending callbacks for the current batch.

#### Scenario: Counter tracks pending callbacks
- **WHEN** a callback is registered for a batch item
- **THEN** `sem-core--pending-callbacks` is incremented

### Requirement: Counter decrements on callback completion
Each callback SHALL decrement `sem-core--pending-callbacks` upon completion.

#### Scenario: Callback decrements counter on completion
- **WHEN** a callback completes successfully
- **THEN** `sem-core--pending-callbacks` is decremented

### Requirement: Barrier fires when counter reaches zero
The planning step SHALL be triggered when `sem-core--pending-callbacks` reaches 0.

#### Scenario: Planning step fires at zero
- **WHEN** the last pending callback completes and counter reaches 0
- **THEN** `sem-core--batch-barrier-check` fires the planning step

### Requirement: sem-core--batch-barrier-check implementation
The function `sem-core--batch-barrier-check` SHALL be called by each callback on completion to check if the barrier should fire.

#### Scenario: Barrier check called on callback completion
- **WHEN** a callback completes
- **THEN** `sem-core--batch-barrier-check` is called to evaluate if barrier should fire

### Requirement: Counter starts at zero triggers immediate planner invocation
When `sem-core--pending-callbacks` starts at 0 (no routed async items in batch), `sem-core-process-inbox` SHALL invoke the planning step immediately.

#### Scenario: Counter starts at zero invokes planner immediately
- **WHEN** `sem-core--pending-callbacks` is 0 at the start of batch processing
- **THEN** `sem-planner-run-planning-step` is called immediately
- **AND** planner exits quickly when temp file has no tasks

### Requirement: Only :link: items fire barrier when captures complete
When the batch contains only `:link:` items (no `:task:` items), URL capture callbacks still count toward pending. The barrier fires when all captures complete. Planning step receives 0 tasks and exits.

#### Scenario: Only :link: items complete after captures
- **WHEN** the batch contains only `:link:` items
- **THEN** URL capture callbacks decrement `sem-core--pending-callbacks`
- **AND** when the last capture completes, `sem-core--batch-barrier-check` is called
- **AND** the planning step receives 0 tasks and exits
