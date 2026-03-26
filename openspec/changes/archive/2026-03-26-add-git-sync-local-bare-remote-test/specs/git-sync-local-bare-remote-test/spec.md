## ADDED Requirements

### Requirement: Local bare-remote git-sync integration path
The system SHALL provide a deterministic integration test path that executes `sem-git-sync-org-roam` against a local bare Git remote using a `file://` URL. The test flow MUST run without OpenRouter access, GitHub access, or SSH key dependencies.

#### Scenario: Local bare remote configured for sync
- **WHEN** the git-sync local integration flow starts
- **THEN** it creates an isolated local repository and a local bare remote
- **AND** it configures `origin` to a `file://` remote path

#### Scenario: No external network or credentials required
- **WHEN** the local git-sync integration flow runs
- **THEN** the flow MUST NOT require `OPENROUTER_KEY`
- **AND** the flow MUST NOT call GitHub APIs or remote hosted git providers
- **AND** the flow MUST NOT require host SSH keys or SSH agent forwarding

### Requirement: Commit propagation to bare remote is verifiable
The system SHALL verify that a successful git-sync with local content changes creates a commit in the local repository and propagates that commit to the configured local bare remote.

#### Scenario: Changed content is committed and pushed
- **WHEN** at least one tracked org-roam file changes before sync
- **THEN** `sem-git-sync-org-roam` produces a successful sync result
- **AND** the local repository `HEAD` advances by one commit
- **AND** the bare remote branch tip matches the local branch tip after push

### Requirement: Clean repository no-op behavior is verifiable
The system SHALL verify that when there are no local content changes, `sem-git-sync-org-roam` reports success as a no-op and does not create new commits.

#### Scenario: No-op sync preserves commit count
- **WHEN** `sem-git-sync-org-roam` runs with a clean working tree
- **THEN** the function returns success
- **AND** the local repository commit count remains unchanged
- **AND** the bare remote branch tip remains unchanged

### Requirement: Failure paths are classified deterministically
The system SHALL verify explicit failure outcomes for invalid local repository state and unavailable push target state.

#### Scenario: Missing or invalid local repository fails
- **WHEN** the local org-roam path is missing or not a valid git repository
- **THEN** `sem-git-sync-org-roam` returns a failure result
- **AND** the failure is recorded as a git-sync failure outcome

#### Scenario: Unavailable push target fails
- **WHEN** the configured local bare remote is unavailable during push
- **THEN** `sem-git-sync-org-roam` returns a failure result
- **AND** no success outcome is reported for that run

### Requirement: Repeated local runs are deterministic
The system SHALL keep artifacts, paths, and cleanup behavior deterministic across repeated local integration runs.

#### Scenario: Repeated runs reuse deterministic structure
- **WHEN** operators run the local git-sync integration flow multiple times
- **THEN** each run uses deterministic artifact directories and naming
- **AND** setup and cleanup leave no ambiguous state between runs
