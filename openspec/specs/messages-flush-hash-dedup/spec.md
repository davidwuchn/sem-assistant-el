## Purpose

This capability defines content-hash deduplication behavior for daily `*Messages*` flushes so unchanged snapshots are not appended repeatedly while preserving rollover and retry correctness.

## Requirements

### Requirement: Daily messages flush skips unchanged content
`sem-core--flush-messages-daily` SHALL compute a deterministic content hash of the current `*Messages*` buffer on each invocation and compare it with the hash from the last successful flush. If the hash is unchanged, the function SHALL skip file append for that invocation.

#### Scenario: Unchanged messages skip append
- **WHEN** `sem-core--flush-messages-daily` runs
- **AND** the current `*Messages*` buffer hash equals the last successfully flushed hash
- **THEN** the function does not append to `/var/log/sem/messages-YYYY-MM-DD.log`

#### Scenario: Changed messages append
- **WHEN** `sem-core--flush-messages-daily` runs
- **AND** the current `*Messages*` buffer hash differs from the last successfully flushed hash
- **THEN** the function appends the current buffer content to `/var/log/sem/messages-YYYY-MM-DD.log`

### Requirement: Dedup state reflects only successful flushes
The stored last-flushed hash SHALL be updated only after a successful append operation. If append fails, the stored hash SHALL remain unchanged so a later retry can still flush pending content.

#### Scenario: Hash state updated after successful append
- **WHEN** append to the daily messages file succeeds
- **THEN** the in-memory last-flushed hash is updated to the hash of the appended snapshot

#### Scenario: Hash state unchanged on append failure
- **WHEN** append to the daily messages file fails
- **THEN** the in-memory last-flushed hash is not updated
- **AND** the same snapshot remains eligible for flush on a later invocation

### Requirement: Date rollover preserves dedup correctness
On UTC date rollover, the flush flow SHALL preserve existing rollover behavior and SHALL treat the new day's post-erase buffer state independently from the prior day's dedup hash.

#### Scenario: Rollover does not suppress new-day first append
- **WHEN** the current UTC date differs from `sem-core--last-flush-date`
- **AND** rollover erase/write flow runs for the new day
- **THEN** the first eligible new-day snapshot is appended to `messages-YYYY-MM-DD.log` for the new date
