## ADDED Requirements

### Requirement: inbox-purge runs daily at 4:00 AM
The system SHALL execute inbox purge daily at 4:00 AM via cron. The purge SHALL remove all headlines from `/data/inbox-mobile.org` whose hashes appear in `/data/.sem-cursor.el`.

#### Scenario: Scheduled purge executes
- **WHEN** the cron schedule triggers at 4:00 AM
- **THEN** `sem-core-purge-inbox` is called via `emacsclient`

#### Scenario: Processed nodes removed
- **WHEN** `.sem-cursor.el` contains hashes of processed headlines
- **THEN** those headlines are removed from `/data/inbox-mobile.org`

### Requirement: Purge is atomic via rename-file
The system SHALL implement purge atomically. The implementation SHALL write purged content to a temporary file (e.g., `/data/.inbox-mobile.org.tmp`), then call `(rename-file tmp-path "/data/inbox-mobile.org" t)`. Direct in-place buffer save or `write-region` to the target path is FORBIDDEN.

#### Scenario: Atomic rename on success
- **WHEN** purge completes successfully
- **THEN** the temporary file is atomically renamed to replace the original

#### Scenario: Crash leaves original untouched
- **WHEN** a crash occurs before `rename-file` completes
- **THEN** the original `/data/inbox-mobile.org` remains unchanged

### Requirement: Purge is the only write window for inbox-mobile.org
The system SHALL NOT write to `/data/inbox-mobile.org` at any time other than the 4:00 AM purge window. This is the exclusive time for modifications to the inbox file.

#### Scenario: No writes outside purge window
- **WHEN** any time other than 4:00 AM
- **THEN** `/data/inbox-mobile.org` is never written to by the daemon

### Requirement: Unprocessed headlines retained
The system SHALL retain headlines that have not been processed (hashes not in `.sem-cursor.el`). Only processed headlines SHALL be removed.

#### Scenario: Unprocessed headlines kept
- **WHEN** `/data/inbox-mobile.org` contains headlines not in the cursor
- **THEN** those headlines remain in the file after purge
