## Purpose

This capability defines a mutex/lock helper mechanism in `sem-router.el` that can serialize concurrent write callbacks when direct shared-file writes are needed.

## Requirements

### Requirement: Boolean flag for write serialization
The system SHALL provide a `defvar` boolean flag `sem-router--tasks-write-lock` with default value `nil`. This flag SHALL act as a mutex for guarded callback sections.

#### Scenario: Flag defaults to nil
- **WHEN** Emacs starts
- **THEN** `sem-router--tasks-write-lock` is bound to `nil`

#### Scenario: Flag is a boolean
- **WHEN** checking the type of `sem-router--tasks-write-lock`
- **THEN** it is either `nil` or `t`

### Requirement: Atomic lock acquisition with unwind-protect
The system SHALL acquire the lock atomically by checking if `sem-router--tasks-write-lock` is `nil` and setting it to `t` in a single operation. The lock SHALL always be released using `unwind-protect` to ensure cleanup even if errors occur.

#### Scenario: Lock acquired when available
- **WHEN** a callback attempts to acquire the lock and it is `nil`
- **THEN** the lock is set to `t` and the callback proceeds

#### Scenario: Lock released after write
- **WHEN** a callback completes its guarded section
- **THEN** the lock is set back to `nil`

#### Scenario: Lock released on error
- **WHEN** an error occurs during the write operation
- **THEN** `unwind-protect` ensures the lock is still set to `nil`

### Requirement: Retry with delay when lock is held
When a callback finds `sem-router--tasks-write-lock` equal to `t`, it SHALL re-schedule itself using `run-with-timer` with a 0.5 second delay. Each callback SHALL track its own retry count.

#### Scenario: Retry scheduled when lock is held
- **WHEN** a callback finds the lock is `t`
- **THEN** it calls `run-with-timer` with 0.5s delay to retry

#### Scenario: Retry count tracked per callback
- **WHEN** a callback retries
- **THEN** it increments its local retry counter

### Requirement: Max 10 retries before DLQ
The system SHALL allow a maximum of 10 retry attempts. After 10 failed retries, the item SHALL be routed to the Dead Letter Queue via `sem-core-log-error` and the lock SHALL NOT be held.

#### Scenario: Item succeeds within 10 retries
- **WHEN** a callback acquires the lock on or before the 10th retry
- **THEN** it executes the guarded callback and releases the lock

#### Scenario: Item routed to DLQ after 10 retries
- **WHEN** a callback fails to acquire the lock after 10 retries
- **THEN** `sem-core-log-error` is called with the item details
- **AND** the guarded callback is not executed

#### Scenario: Lock not held after DLQ
- **WHEN** an item is routed to DLQ after exhausting retries
- **THEN** the lock remains `nil` (not held by the failed callback)

### Requirement: Lock never held across retries
The lock SHALL be acquired and released within each retry attempt. The lock SHALL NOT be held while waiting for the next retry.

#### Scenario: Lock released before retry delay
- **WHEN** a callback cannot acquire the lock
- **THEN** it does not hold the lock during the 0.5s delay period

#### Scenario: Each attempt is independent
- **WHEN** a callback retries
- **THEN** each attempt independently tries to acquire and release the lock
