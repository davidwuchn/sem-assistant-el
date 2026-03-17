## Purpose

TBD

## Requirements

### Requirement: Teardown SSH agent after git sync
After `git push origin` completes (success or failure), the system SHALL unconditionally call `ssh-agent -k` using the `SSH_AGENT_PID` environment variable. The teardown SHALL be implemented via `unwind-protect` in `sem-git-sync-org-roam` so it runs even if the push raises a condition.

#### Scenario: Agent killed after successful push
- **WHEN** `git push origin` completes successfully
- **THEN** `ssh-agent -k` is called to kill the agent

#### Scenario: Agent killed after failed push
- **WHEN** `git push origin` fails with an error
- **THEN** `ssh-agent -k` is still called to kill the agent

#### Scenario: Agent killed even if push raises condition
- **WHEN** `git push origin` signals an error/condition
- **THEN** `ssh-agent -k` is still called via `unwind-protect`

### Requirement: Only kill agents spawned in current cycle
If `SSH_AGENT_PID` is nil OR the agent was pre-existing (reused), the system SHALL NOT kill it. The system SHALL only kill agents that were spawned in the current sync cycle. A boolean local variable `sem-git-sync--agent-spawned-this-cycle` SHALL track this state.

#### Scenario: Pre-existing agent not killed
- **WHEN** an existing agent was reused (not spawned)
- **AND** `sem-git-sync--agent-spawned-this-cycle` is nil
- **THEN** `ssh-agent -k` SHALL NOT be called

#### Scenario: Freshly spawned agent is killed
- **WHEN** a new agent was spawned in this sync cycle
- **AND** `sem-git-sync--agent-spawned-this-cycle` is t
- **THEN** `ssh-agent -k` SHALL be called with the spawned agent's PID

#### Scenario: Missing SSH_AGENT_PID prevents kill
- **WHEN** `SSH_AGENT_PID` is nil
- **THEN** `ssh-agent -k` SHALL NOT be called
