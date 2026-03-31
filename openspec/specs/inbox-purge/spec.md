## Purpose

This capability defines the inbox purge mechanism that removes processed headlines from inbox-mobile.org during the 4AM window.

## Requirements

### Requirement: inbox-purge runs daily at 4:00 AM
The system SHALL execute inbox purge daily at 4:00 AM via cron interpreted in `CLIENT_TIMEZONE`. The purge SHALL remove all headlines from `/data/inbox-mobile.org` whose hashes appear in `/data/.sem-cursor.el`.

#### Scenario: Scheduled purge executes
- **WHEN** the cron schedule triggers at 4:00 AM in `CLIENT_TIMEZONE`
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
The system SHALL NOT write to `/data/inbox-mobile.org` at any time other than the 4:00 AM purge window in `CLIENT_TIMEZONE`. This is the exclusive time for modifications to the inbox file.

#### Scenario: No writes outside purge window
- **WHEN** any time other than 4:00 AM in `CLIENT_TIMEZONE`
- **THEN** `/data/inbox-mobile.org` is never written to by the daemon

### Requirement: Purge hash computation matches router format
The system SHALL compute headline hashes in `sem-core-purge-inbox` using exactly the same format as `sem-router--parse-headlines`. The hash input SHALL be `(concat org-element-title "|" space-joined-tags "|" body)` where `space-joined-tags` is the space-separated list of tags (without colons).

#### Scenario: Hash matches router computation
- **WHEN** `sem-core-purge-inbox` computes a hash for comparison
- **THEN** it uses `(concat title "|" space-joined-tags "|" body)` format
- **AND** this matches the hash stored by `sem-router--parse-headlines`

#### Scenario: Tags are space-joined without colons
- **WHEN** a headline has tags `:tag1:tag2:`
- **THEN** the hash input uses `"tag1 tag2"` (space-separated, no colons)

#### Scenario: Body is included in hash
- **WHEN** a headline has body content
- **THEN** the body text is appended to the hash input after the tags

### Requirement: Unprocessed headlines retained
The system SHALL retain headlines that have not been processed (hashes not in `.sem-cursor.el`). Only processed headlines SHALL be removed. The implementation SHALL preserve the full subtree of each unprocessed headline (title line + all body lines until the next top-level `* ` headline or EOF). The temp-file write MUST use region-based or org-element-based copy — writing only the title string is FORBIDDEN.

#### Scenario: Unprocessed headlines kept with full body
- **WHEN** `/data/inbox-mobile.org` contains headlines not in the cursor
- **THEN** those headlines remain in the file with all body lines preserved after purge

#### Scenario: Full subtree copied to temp file
- **WHEN** purge processes an unprocessed headline
- **THEN** the title line and all body lines (until next `* ` or EOF) are copied to the temp file

#### Scenario: Region-based copy implementation
- **WHEN** `sem-core-purge-inbox` writes unprocessed content
- **THEN** it uses region-based or org-element-based copy, not title-string-only write
