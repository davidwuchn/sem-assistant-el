## MODIFIED Requirements

### Requirement: org-roam DB always rebuilt
The system SHALL always delete `/data/org-roam/org-roam.db` (and `*.db-shm`, `*.db-wal`) if they exist, then call `(org-roam-db-sync)` to rebuild from all `.org` files in `/data/org-roam/org-files/`.

#### Scenario: org-roam DB rebuilt on startup
- **WHEN** the daemon starts
- **THEN** existing `org-roam.db` is deleted and rebuilt via `org-roam-db-sync`

#### Scenario: Pre-placed org files indexed
- **WHEN** `/data/org-roam/org-files/` contains `.org` files placed before first startup
- **THEN** those files are indexed by `org-roam-db-sync`

#### Scenario: Empty notes root produces empty DB
- **WHEN** `/data/org-roam/org-files/` is empty or does not exist
- **THEN** `org-roam-db-sync` produces an empty DB without error
