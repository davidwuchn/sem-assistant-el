## Purpose

Define batch identity isolation rules for asynchronous inbox callbacks so stale callbacks cannot mutate active-batch state.

## Requirements

### Requirement: Async callbacks carry immutable batch identity
Every asynchronous inbox-processing unit SHALL carry the batch identity captured at dispatch time. Callback execution SHALL validate this identity before mutating counters, writing outputs, or triggering planning.

#### Scenario: Callback with matching batch identity
- **WHEN** an async callback returns with the same batch identity as the active batch
- **THEN** callback side effects are allowed for that batch

#### Scenario: Callback with stale batch identity
- **WHEN** an async callback returns with a batch identity that does not match the active batch
- **THEN** callback side effects are rejected
- **AND** the stale callback is logged as ignored

### Requirement: Barrier and watchdog are batch-owned
Barrier accounting and watchdog timeout handling SHALL be scoped to the owning batch identity. A barrier decrement or watchdog event from a non-owning batch SHALL NOT affect active-batch completion state.

#### Scenario: Barrier decrement from owning batch
- **WHEN** pending callback count is decremented for the owning batch
- **THEN** only that batch's barrier state is updated

#### Scenario: Watchdog event from stale batch
- **WHEN** a watchdog callback fires for a stale batch identity
- **THEN** no planning trigger or barrier mutation occurs for the active batch

### Requirement: Batch temp writes are identity validated
Pass 1 output writes to `/tmp/data/tasks-tmp-{batch-id}.org` SHALL validate that callback batch identity matches the target file batch identity. Mismatched writes SHALL be dropped without fallback to another batch file.

#### Scenario: Valid batch temp write
- **WHEN** callback batch identity matches target temp file batch identity
- **THEN** output is appended to `/tmp/data/tasks-tmp-{batch-id}.org`

#### Scenario: Mismatched batch temp write
- **WHEN** callback batch identity does not match target temp file batch identity
- **THEN** output write is skipped
- **AND** output is not redirected into the active batch file

### Requirement: Planning trigger is evaluated only by owning batch
The planning step trigger condition (pending callbacks reaching zero) SHALL be evaluated only for the batch that owns the callbacks. Stale callbacks SHALL NOT trigger planning for another batch.

#### Scenario: Owning batch reaches barrier zero
- **WHEN** pending callbacks for the owning batch reach zero
- **THEN** planning is triggered exactly for that batch

#### Scenario: Stale callback arrives after newer batch started
- **WHEN** a stale callback from an older batch completes while a newer batch is active
- **THEN** planning for the newer batch is not triggered by the stale callback
