## Purpose

This capability defines the database initialization and bootstrap checks for Elfeed and org-roam databases on daemon startup.

## Requirements

### Requirement: Bootstrap check runs on every daemon startup
The system SHALL run a bootstrap check for both Elfeed DB and org-roam DB on every daemon startup. This check SHALL run once, synchronously, before the daemon accepts any `emacsclient` connections.

#### Scenario: Bootstrap runs before accepting connections
- **WHEN** the Emacs daemon starts
- **THEN** bootstrap check completes before any `emacsclient` connections are accepted

### Requirement: Elfeed DB loaded or recreated on corruption
The system SHALL attempt `(elfeed-db-load)` on startup. If it succeeds, the existing DB SHALL be kept. If it raises an error (corrupt DB), `/data/elfeed/` SHALL be deleted entirely and `(elfeed-db-load)` called again to create a fresh empty DB.

#### Scenario: Existing DB loaded
- **WHEN** `/data/elfeed/` contains a valid Elfeed database
- **THEN** `(elfeed-db-load)` succeeds and entries are preserved

#### Scenario: Corrupt DB wiped and recreated
- **WHEN** `(elfeed-db-load)` raises an error
- **THEN** `/data/elfeed/` is deleted and a fresh empty DB is created

#### Scenario: Elfeed DB never proactively wiped
- **WHEN** the daemon starts with a valid Elfeed DB
- **THEN** the DB is not wiped; entries from before container restart are preserved

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

### Requirement: org-roam DB rebuild errors logged and continued
The system SHALL handle `org-roam-db-sync` errors gracefully. If `org-roam-db-sync` raises an error (e.g., malformed `.org` file), the error SHALL be logged to `/data/errors.org` and the daemon SHALL continue — it must not abort due to a corrupt note file.

#### Scenario: Malformed org file logged
- **WHEN** `org-roam-db-sync` encounters a malformed `.org` file
- **THEN** the error is logged to `/data/errors.org` and the daemon continues

### Requirement: feeds.org parsed by internal loader
The system SHALL parse `/data/feeds.org` via an internal feeds loader during startup refresh.
If `/data/feeds.org` does not exist, Elfeed SHALL start with an empty feed list and no error is raised.

#### Scenario: feeds.org loaded
- **WHEN** `/data/feeds.org` exists
- **THEN** the internal loader parses feed subscriptions from it

#### Scenario: Missing feeds.org handled
- **WHEN** `/data/feeds.org` does not exist
- **THEN** elfeed starts with an empty feed list without error
