## Purpose

TBD

## Requirements

### Requirement: cl-block wrapper for early exit
The entire function body of `sem-git-sync-org-roam` SHALL be wrapped in `(cl-block sem-git-sync-org-roam ...)` immediately inside the `condition-case` wrapper. The `condition-case` MUST remain as the outermost wrapper; `cl-block` MUST be the direct child of `condition-case`'s body. All existing `(cl-return-from sem-git-sync-org-roam ...)` call sites SHALL remain functional without signaling Lisp errors.

#### Scenario: Early exit on missing directory
- **WHEN** `sem-git-sync-org-roam` is called and the org-roam directory does not exist
- **THEN** the function calls `(cl-return-from sem-git-sync-org-roam nil)`
- **AND** the function SHALL return `nil` without signaling `(error "Return from unknown block")`
- **AND** the `condition-case` handler SHALL NOT be triggered by the `cl-return-from` call

#### Scenario: Early exit on git setup failure
- **WHEN** the git directory check fails (e.g., `git rev-parse --git-dir` returns non-zero)
- **THEN** the function calls `(cl-return-from sem-git-sync-org-roam nil)`
- **AND** the function SHALL return `nil` without signaling a Lisp error

#### Scenario: Successful sync with no changes
- **WHEN** there are no changes to commit (repository is clean)
- **THEN** the function SHALL return `t` indicating successful no-op
- **AND** no commit or push SHALL be attempted
- **AND** no Lisp error SHALL be signaled

#### Scenario: Successful sync with changes
- **WHEN** there are changes to commit
- **THEN** the function SHALL commit all changes and push to origin
- **AND** the function SHALL return a non-nil value on success
- **AND** no Lisp error SHALL be signaled

#### Scenario: SSH setup failure handling
- **WHEN** `sem-git-sync--setup-ssh` returns `nil`
- **THEN** the function calls `(cl-return-from sem-git-sync-org-roam nil)`
- **AND** the function SHALL return `nil` without signaling a Lisp error
