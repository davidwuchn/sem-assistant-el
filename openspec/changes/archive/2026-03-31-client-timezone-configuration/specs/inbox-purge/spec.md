## MODIFIED Requirements

### Requirement: inbox-purge runs daily at 4:00 AM
The system SHALL execute inbox purge daily at 4:00 AM via cron interpreted in `CLIENT_TIMEZONE`. The purge SHALL remove all headlines from `/data/inbox-mobile.org` whose hashes appear in `/data/.sem-cursor.el`.

#### Scenario: Scheduled purge executes
- **WHEN** the cron schedule triggers at 4:00 AM in `CLIENT_TIMEZONE`
- **THEN** `sem-core-purge-inbox` is called via `emacsclient`

#### Scenario: Processed nodes removed
- **WHEN** `.sem-cursor.el` contains hashes of processed headlines
- **THEN** those headlines are removed from `/data/inbox-mobile.org`

### Requirement: Purge is the only write window for inbox-mobile.org
The system SHALL NOT write to `/data/inbox-mobile.org` at any time other than the 4:00 AM purge window in `CLIENT_TIMEZONE`. This is the exclusive time for modifications to the inbox file.

#### Scenario: No writes outside purge window
- **WHEN** any time other than 4:00 AM in `CLIENT_TIMEZONE`
- **THEN** `/data/inbox-mobile.org` is never written to by the daemon
