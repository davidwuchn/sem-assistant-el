## ADDED Requirements

### Requirement: sem-git-sync module loaded during initialization
The system SHALL load the `sem-git-sync` module during initialization via `(require 'sem-git-sync)` in `sem-init--load-modules`. The require call SHALL be placed after `(require 'sem-url-capture)` and before `(require 'sem-router)`.

#### Scenario: sem-git-sync loaded after sem-url-capture
- **WHEN** `sem-init--load-modules` executes
- **THEN** `(require 'sem-git-sync)` is called after `(require 'sem-url-capture)`

#### Scenario: sem-git-sync loaded before sem-router
- **WHEN** `sem-init--load-modules` executes
- **THEN** `(require 'sem-git-sync)` is called before `(require 'sem-router)`

#### Scenario: sem-git-sync-org-roam function bound after load
- **WHEN** `sem-init--load-modules` completes
- **THEN** `fboundp 'sem-git-sync-org-roam` returns `t`
