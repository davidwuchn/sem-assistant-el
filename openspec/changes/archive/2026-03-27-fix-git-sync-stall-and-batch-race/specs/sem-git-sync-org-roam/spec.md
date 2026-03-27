## ADDED Requirements

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
