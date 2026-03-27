## ADDED Requirements

### Requirement: Git sync commands execute without shell-string parsing
`sem-git-sync--run-command` SHALL execute commands via argv-based process APIs using a program and explicit argument list. The function SHALL NOT execute shell command strings for git-sync operations.

#### Scenario: Program and args passed separately
- **WHEN** `sem-git-sync--run-command` is invoked
- **THEN** the implementation executes a program name with explicit argv arguments
- **AND** it does not invoke shell-string command execution

#### Scenario: Arguments containing shell metacharacters are treated as literals
- **WHEN** an argument contains characters such as spaces, semicolons, or ampersands
- **THEN** the command runner passes the argument as a literal argv element
- **AND** no shell interpretation is applied

### Requirement: Command result semantics remain compatible for callers
The argv-based command runner SHALL preserve caller-visible success/failure semantics by returning status and combined output in the same shape expected by existing git-sync call sites.

#### Scenario: Successful command preserves expected success semantics
- **WHEN** a git command exits with status code 0
- **THEN** `sem-git-sync--run-command` reports success in the same caller-visible manner as before

#### Scenario: Failing command preserves expected failure semantics
- **WHEN** a git command exits with non-zero status
- **THEN** `sem-git-sync--run-command` reports failure in the same caller-visible manner as before
- **AND** callers can inspect command output for diagnostics
