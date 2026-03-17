## ADDED Requirements

### Requirement: Module load test for sem-git-sync
The system SHALL provide an ERT test that verifies `sem-git-sync` is properly loaded by `sem-init--load-modules`. The test SHALL be located in `app/elisp/tests/sem-init-test.el` (or appropriate test file).

#### Scenario: sem-git-sync required during module loading
- **WHEN** `sem-init--load-modules` is called (with all `require` calls mocked to no-ops)
- **THEN** `sem-git-sync` is among the required modules
- **AND** `fboundp 'sem-git-sync-org-roam` returns `t` after load

#### Scenario: Module load order verified
- **WHEN** the module load test executes
- **THEN** it verifies `sem-git-sync` is loaded after `sem-url-capture`
- **AND** it verifies `sem-git-sync` is loaded before `sem-router`
