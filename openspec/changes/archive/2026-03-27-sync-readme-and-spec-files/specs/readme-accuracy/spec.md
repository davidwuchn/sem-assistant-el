## MODIFIED Requirements

### Requirement: README content matches current repository behavior
The README SHALL remain aligned with current code paths, executable commands, and documented operational behavior, and SHALL remove or correct stale references.

#### Scenario: Commands are executable or explicitly illustrative
- **WHEN** a command example appears in README
- **THEN** it MUST be executable from the documented location
- **AND** if an example is illustrative only, it MUST be explicitly labeled as illustrative

#### Scenario: Paths and component names match the repository
- **WHEN** README references files, directories, or modules
- **THEN** referenced paths and names MUST match the current repository structure
- **AND** stale or renamed paths MUST NOT remain in documentation

#### Scenario: Missing prerequisite behavior is documented
- **WHEN** required tools, environment variables, or certificate prerequisites are absent
- **THEN** README MUST document expected failure modes or operator actions
- **AND** README MUST include guidance for missing tools, missing environment variables, and certificate renewal prerequisites
