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

### Requirement: Sync-needed detection includes ahead-of-upstream state
`sem-git-sync-org-roam` SHALL determine sync-needed state using both working-tree changes and branch divergence with upstream. The function SHALL attempt sync when local branch is ahead of upstream even if `git status --porcelain` is clean.

#### Scenario: Ahead with clean working tree
- **WHEN** local branch has unpushed commits and working tree is clean
- **THEN** `sem-git-sync-org-roam` treats the repository as sync-needed
- **AND** the run does not exit as a permanent no-op skip

#### Scenario: Not ahead and no local changes
- **WHEN** local branch is not ahead of upstream and working tree is clean
- **THEN** `sem-git-sync-org-roam` may complete as no-op success without commit or push

### Requirement: Pull-before-push is mandatory for sync runs
For sync-needed runs, `sem-git-sync-org-roam` SHALL perform pull reconciliation before attempting push. If pull fails, push SHALL NOT be attempted in that run.

#### Scenario: Pull succeeds before push
- **WHEN** a sync-needed run starts and pull reconciliation succeeds
- **THEN** push is attempted after pull completion

#### Scenario: Pull fails before push
- **WHEN** pull reconciliation fails during a sync-needed run
- **THEN** the run exits failure
- **AND** push is not attempted

### Requirement: Pull and push failures are explicitly classified
Failures in pull or push phases SHALL be logged with explicit failure classification (including conflict/authentication/network categories where detectable). The run SHALL not be reported as `SKIP` when unpushed local commits remain.

#### Scenario: Push failure after local commit exists
- **WHEN** push fails and local branch remains ahead of upstream
- **THEN** failure is logged with explicit classification
- **AND** subsequent runs continue to treat ahead state as sync-needed

#### Scenario: Pull conflict classification
- **WHEN** pull reconciliation fails due to conflict
- **THEN** the run records conflict-classified failure
- **AND** the failure is visible in sync logs as non-success
