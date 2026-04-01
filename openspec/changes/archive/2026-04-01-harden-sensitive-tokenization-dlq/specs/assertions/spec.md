## MODIFIED Requirements

### Requirement: Assertions validate test outcomes
Integration assertions SHALL cover malformed-sensitive fixture behavior as a terminal DLQ/security flow. Assertion coverage MUST verify malformed-sensitive fixtures are excluded from expected post-run task output, and MUST verify security evidence in both `errors.org` and `sem-log.org`.

#### Scenario: Malformed-sensitive fixture excluded from tasks count
- **WHEN** integration fixtures include a malformed-sensitive task
- **THEN** expected final `tasks.org` TODO count excludes that fixture

#### Scenario: Malformed-sensitive fixture absent from tasks output
- **WHEN** assertions inspect `tasks.org`
- **THEN** malformed-sensitive fixture title is not present

#### Scenario: Malformed-sensitive fixture logged as security priority
- **WHEN** assertions inspect `errors.org`
- **THEN** there is an entry for the malformed-sensitive fixture with `[#A]` and `:security:`

#### Scenario: Malformed-sensitive fixture has DLQ/security log evidence
- **WHEN** assertions inspect `sem-log.org`
- **THEN** there is a DLQ/security preflight failure log for the malformed-sensitive fixture
