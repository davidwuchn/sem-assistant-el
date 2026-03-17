## MODIFIED Requirements

### Requirement: SSH agent environment setup
The `sem-git-sync--setup-ssh` function SHALL check for an existing SSH agent before spawning a new one. If `SSH_AUTH_SOCK` is set and the socket file exists, it SHALL reuse the existing agent. Otherwise, it SHALL start `ssh-agent` and capture its environment variables by parsing the stdout output. The function MUST set `SSH_AUTH_SOCK` and `SSH_AGENT_PID` in the Emacs process environment using `setenv` before attempting `ssh-add`. The function SHALL return `t` on success (agent reused or freshly spawned + key added) and `nil` on failure. It SHALL also return a second value indicating which path was taken (reused or spawned) for testability.

#### Scenario: Successful SSH agent setup with new spawn
- **WHEN** `sem-git-sync--setup-ssh` is called
- **AND** no existing agent is detected
- **THEN** it executes `ssh-agent -s` and parses the output for `SSH_AUTH_SOCK=<path>` and `SSH_AGENT_PID=<pid>`
- **AND** it calls `(setenv "SSH_AUTH_SOCK" <path>)` and `(setenv "SSH_AGENT_PID" <pid>)` in the Emacs process
- **AND** it proceeds to call `ssh-add` with the configured SSH key
- **AND** it returns `t` and a second value indicating spawn path

#### Scenario: Successful SSH agent reuse
- **WHEN** `sem-git-sync--setup-ssh` is called
- **AND** `SSH_AUTH_SOCK` is set to a valid socket path
- **AND** the socket file exists on disk
- **THEN** it skips `ssh-agent -s` execution
- **AND** it proceeds directly to `ssh-add` with the configured SSH key
- **AND** it returns `t` and a second value indicating reuse path

#### Scenario: SSH agent output parsing with regex
- **WHEN** `ssh-agent -s` returns output in the format `SSH_AUTH_SOCK=/tmp/ssh-xxx/agent.yyy; export SSH_AUTH_SOCK;`
- **THEN** the function SHALL extract the value using regex pattern `SSH_AUTH_SOCK=\\([^;]+\\)`
- **AND** when output contains `SSH_AGENT_PID=123; export SSH_AGENT_PID;`
- **THEN** the function SHALL extract the PID using regex pattern `SSH_AGENT_PID=\\([0-9]+\\)`

#### Scenario: Missing SSH_AUTH_SOCK in agent output
- **WHEN** `ssh-agent -s` output does not contain a match for `SSH_AUTH_SOCK`
- **THEN** the function SHALL log FAIL and return `nil`

#### Scenario: Missing SSH_AGENT_PID in agent output
- **WHEN** `ssh-agent -s` output does not contain a match for `SSH_AGENT_PID`
- **THEN** the function SHALL log FAIL and return `nil`

#### Scenario: SSH agent command failure
- **WHEN** `ssh-agent -s` returns a non-zero exit code
- **THEN** the function SHALL log FAIL and return `nil`

### Requirement: cl-block wrapper for early exit
The entire function body of `sem-git-sync--setup-ssh` SHALL be wrapped in `(cl-block sem-git-sync--setup-ssh ...)` immediately inside the `condition-case` wrapper. All existing `(cl-return-from sem-git-sync--setup-ssh ...)` call sites SHALL remain functional without signaling Lisp errors.

#### Scenario: Early exit via cl-return-from
- **WHEN** the function encounters an error condition and calls `(cl-return-from sem-git-sync--setup-ssh nil)`
- **THEN** the function SHALL return `nil` without signaling `(error "Return from unknown block")`
- **AND** the `condition-case` handler SHALL NOT be triggered by the `cl-return-from` call

#### Scenario: Successful completion
- **WHEN** the function completes successfully after setting up SSH
- **THEN** it SHALL return `t` and a second value
- **AND** no Lisp error SHALL be signaled
