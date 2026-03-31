## ADDED Requirements

### Requirement: Daily cursor purge rebuilds active headline hashes only
During the 4:00 AM purge window, the system SHALL rebuild `/data/.sem-cursor.el` to contain only hashes for headlines that remain in `/data/inbox-mobile.org` after purge retention logic completes.

#### Scenario: Cursor rebuilt from retained headlines
- **WHEN** `sem-core-purge-inbox` runs during the 4:00 AM window and keeps unprocessed headlines
- **THEN** `/data/.sem-cursor.el` is rewritten to contain only hashes of those retained headlines

#### Scenario: Removed headlines are dropped from cursor
- **WHEN** a headline is removed from `/data/inbox-mobile.org` during purge
- **THEN** its hash is absent from the rebuilt cursor file

#### Scenario: Missing inbox yields empty active cursor
- **WHEN** `/data/inbox-mobile.org` does not exist during the 4:00 AM purge window
- **THEN** `/data/.sem-cursor.el` is rebuilt as an empty alist

### Requirement: Cursor purge runs only in daily purge window
The system SHALL NOT rebuild `/data/.sem-cursor.el` outside the 4:00 AM purge window.

#### Scenario: No cursor purge outside window
- **WHEN** `sem-core-purge-inbox` executes outside the 4:00 AM hour
- **THEN** cursor purge is skipped

### Requirement: Cursor purge failure is isolated
Failure in cursor purge SHALL be isolated and MUST NOT prevent inbox purge completion or retries purge execution.

#### Scenario: Cursor purge error does not abort purge flow
- **WHEN** cursor rebuild raises an error
- **THEN** the error is logged
- **AND** the overall purge flow continues for remaining purge steps
