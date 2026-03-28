## MODIFIED Requirements

### Requirement: org-roam directory is a git repository
The system SHALL initialize `/data/org-roam/` as a git repository. During `db-initialization`, after notes-root configuration is resolved, `init.el` SHALL check if `/data/org-roam/.git/` exists. If not, it SHALL run `(call-process "git" nil nil nil "init" "/data/org-roam/")`. This readiness behavior SHALL remain bound to repository root and SHALL NOT move to `/data/org-roam/org-files/`.

#### Scenario: Git repo initialized on first startup
- **WHEN** the daemon starts and `/data/org-roam/.git/` does not exist
- **THEN** `git init` is run in `/data/org-roam/`

#### Scenario: Existing git repo preserved
- **WHEN** the daemon starts and `/data/org-roam/.git/` already exists
- **THEN** no git init is run

### Requirement: Daemon only creates new .org files
The daemon's write contract is: **daemon only ever creates new `.org` files in `/data/org-roam/org-files/` — it never modifies or deletes existing ones**. This is a hard constraint.

#### Scenario: New files created
- **WHEN** url-capture processes a new article
- **THEN** a new `.org` file is created in `/data/org-roam/org-files/`

#### Scenario: Existing files not modified
- **WHEN** the daemon runs
- **THEN** it does not modify existing `.org` files in `/data/org-roam/org-files/`

#### Scenario: Existing files not deleted
- **WHEN** the daemon runs
- **THEN** it does not delete existing `.org` files in `/data/org-roam/org-files/`
