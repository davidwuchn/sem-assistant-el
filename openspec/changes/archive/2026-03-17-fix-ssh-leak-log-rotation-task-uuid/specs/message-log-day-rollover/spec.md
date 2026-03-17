## ADDED Requirements

### Requirement: Track last flush date
The module-level variable `sem-core--last-flush-date` (string, `"YYYY-MM-DD"` format, initially `""`) SHALL store the date of the last flush.

#### Scenario: Initial state is empty string
- **WHEN** the module loads
- **THEN** `sem-core--last-flush-date` is initialized to `""`

### Requirement: Erase buffer on date rollover
On each invocation, if `today != sem-core--last-flush-date`, the system SHALL erase the `*Messages*` buffer (`erase-buffer` inside `with-current-buffer "*Messages*"`), then write to the new day's file, then update `sem-core--last-flush-date`. The erase SHALL happen BEFORE writing so the write captures the first message of the new day.

#### Scenario: Buffer erased on new day
- **WHEN** the current date is 2026-03-18
- **AND** `sem-core--last-flush-date` is `"2026-03-17"`
- **THEN** the `*Messages*` buffer is erased BEFORE writing
- **AND** messages are written to `messages-2026-03-18.log`
- **AND** `sem-core--last-flush-date` is updated to `"2026-03-18"`

#### Scenario: New day's file starts clean
- **WHEN** date rollover occurs
- **THEN** the new day's log file contains only messages from the new day
- **AND** old messages do not bleed into the new file

#### Scenario: No erase on same day
- **WHEN** the current date equals `sem-core--last-flush-date`
- **THEN** the `*Messages*` buffer is NOT erased
- **AND** messages continue appending to the same day's file

#### Scenario: First message captured after erase
- **WHEN** date rollover triggers buffer erase
- **THEN** the write operation captures messages that occur after the erase
- **AND** the first message of the new day is included in the new file
