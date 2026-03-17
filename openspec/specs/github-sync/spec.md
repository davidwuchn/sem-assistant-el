## Purpose

TBD

## Requirements

### Requirement: Automated org-roam sync
The system SHALL provide a cron-scheduled job to synchronize the `/data/org-roam` directory to a remote GitHub repository. The sync MUST commit all changes and push to `origin` using the SSH key mounted at `/root/.ssh`.

#### Scenario: Successful sync
- **WHEN** the cron job triggers
- **THEN** the system commits all tracked and untracked changes in `/data/org-roam` (respecting `.gitignore`) and pushes them to the remote repository.

#### Scenario: Sync with no changes
- **WHEN** the cron job triggers and there are no modifications in `/data/org-roam`
- **THEN** the system logs the skip and does not attempt to create an empty commit or push.
