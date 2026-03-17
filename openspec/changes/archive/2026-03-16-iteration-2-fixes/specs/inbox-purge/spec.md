## MODIFIED Requirements

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
