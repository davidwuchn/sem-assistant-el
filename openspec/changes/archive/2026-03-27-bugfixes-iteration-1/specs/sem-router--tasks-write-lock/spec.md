## MODIFIED Requirements

### Requirement: Atomic lock acquisition with unwind-protect
The system SHALL acquire the lock atomically by checking if `sem-router--tasks-write-lock` is `nil` and setting it to `t` in a single operation. The lock SHALL always be released using `unwind-protect` to ensure cleanup even if errors occur. Async task temp-file write callbacks SHALL execute their write section through the same guarded lock path.

#### Scenario: Lock acquired when available
- **WHEN** a callback attempts to acquire the lock and it is `nil`
- **THEN** the lock is set to `t` and the callback proceeds

#### Scenario: Lock released after write
- **WHEN** a callback completes its guarded section
- **THEN** the lock is set back to `nil`

#### Scenario: Lock released on error
- **WHEN** an error occurs during the write operation
- **THEN** `unwind-protect` ensures the lock is still set to `nil`

#### Scenario: Async task temp-file write uses guarded path
- **WHEN** a `:task:` headline callback writes Pass 1 output to the batch temp file
- **THEN** the write is executed inside `sem-router--with-tasks-write-lock`
- **AND** no direct unguarded temp-file write path is used for that callback
