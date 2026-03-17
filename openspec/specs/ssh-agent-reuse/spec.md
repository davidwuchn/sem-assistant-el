## Purpose

TBD

## Requirements

### Requirement: Check existing SSH agent before spawning
Before spawning a new `ssh-agent`, the system SHALL check whether `SSH_AUTH_SOCK` environment variable is set AND the socket path exists on disk (`file-exists-p`). If both conditions are true, the system SHALL skip `ssh-agent -s` and proceed directly to `ssh-add`. A new agent SHALL only be spawned if the check fails.

#### Scenario: Existing agent socket detected and reused
- **WHEN** `SSH_AUTH_SOCK` is set to `/tmp/ssh-xxx/agent.yyy`
- **AND** the file `/tmp/ssh-xxx/agent.yyy` exists on disk
- **THEN** the system SHALL NOT execute `ssh-agent -s`
- **AND** the system SHALL proceed directly to `ssh-add`

#### Scenario: Missing SSH_AUTH_SOCK triggers new agent spawn
- **WHEN** `SSH_AUTH_SOCK` environment variable is nil or unset
- **THEN** the system SHALL spawn a new `ssh-agent` via `ssh-agent -s`

#### Scenario: Non-existent socket file triggers new agent spawn
- **WHEN** `SSH_AUTH_SOCK` is set to `/tmp/ssh-xxx/agent.yyy`
- **AND** the file `/tmp/ssh-xxx/agent.yyy` does NOT exist on disk
- **THEN** the system SHALL spawn a new `ssh-agent` via `ssh-agent -s`

#### Scenario: Agent reuse returns success
- **WHEN** an existing agent is successfully reused
- **THEN** `sem-git-sync--setup-ssh` SHALL return `t` as the first value
- **AND** SHALL return a second value indicating the reuse path was taken
