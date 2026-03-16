## ADDED Requirements

### Requirement: org-roam directory is a git repository
The system SHALL initialize `/data/org-roam/` as a git repository. During `db-initialization`, after `org-roam-directory` is set, `init.el` SHALL check if `/data/org-roam/.git/` exists. If not, it SHALL run `(call-process "git" nil nil nil "init" "/data/org-roam/")`.

#### Scenario: Git repo initialized on first startup
- **WHEN** the daemon starts and `/data/org-roam/.git/` does not exist
- **THEN** `git init` is run in `/data/org-roam/`

#### Scenario: Existing git repo preserved
- **WHEN** the daemon starts and `/data/org-roam/.git/` already exists
- **THEN** no git init is run

### Requirement: SQLite DB files gitignored
The system SHALL write `/data/org-roam/.gitignore` with entries: `org-roam.db`, `*.db-shm`, `*.db-wal`. The SQLite database SHALL never be committed to git.

#### Scenario: .gitignore created
- **WHEN** git repo is initialized
- **THEN** `.gitignore` is written with SQLite DB exclusions

#### Scenario: DB files not committed
- **WHEN** git status is checked
- **THEN** `org-roam.db` and related files are ignored

### Requirement: SSH credentials volume declared
A read-only SSH credentials volume SHALL be declared in docker-compose for the Emacs container: `~/.ssh/vps-org-roam:/root/.ssh:ro`. This volume is currently empty/unused but pre-wired for future github-integration.

#### Scenario: SSH volume declared
- **WHEN** inspecting `docker-compose.yml`
- **THEN** the SSH credentials volume is declared

#### Scenario: Volume is read-only
- **WHEN** inspecting the volume mount
- **THEN** it is mounted with `:ro` (read-only) flag

### Requirement: Daemon only creates new .org files
The daemon's write contract is: **daemon only ever creates new `.org` files in `/data/org-roam/` — it never modifies or deletes existing ones**. This is a hard constraint.

#### Scenario: New files created
- **WHEN** url-capture processes a new article
- **THEN** a new `.org` file is created in `/data/org-roam/`

#### Scenario: Existing files not modified
- **WHEN** the daemon runs
- **THEN** it does not modify existing `.org` files in `/data/org-roam/`

#### Scenario: Existing files not deleted
- **WHEN** the daemon runs
- **THEN** it does not delete existing `.org` files in `/data/org-roam/`

### Requirement: Conflict resolution out of scope
Conflict resolution is explicitly out of scope for this capability.

#### Scenario: No automatic conflict resolution
- **WHEN** a merge conflict occurs
- **THEN** it must be resolved manually by the operator
