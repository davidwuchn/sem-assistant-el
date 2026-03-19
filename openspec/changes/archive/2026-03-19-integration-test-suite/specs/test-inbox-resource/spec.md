## ADDED Requirements

### Requirement: Test inbox resource file exists
The system SHALL provide a test inbox org file at `dev/integration/testing-resources/inbox-tasks.org` that exercises the inbox processing pipeline.

#### Scenario: Test inbox has exactly three headlines
- **WHEN** the test inbox is loaded
- **THEN** it MUST contain exactly 3 headlines, each tagged with `@task`

#### Scenario: Test inbox has routine-tagged headline
- **WHEN** the test inbox is parsed
- **THEN** one headline MUST be tagged with both `@task` and `:routine:`

#### Scenario: Test inbox has work-tagged headline
- **WHEN** the test inbox is parsed
- **THEN** one headline MUST be tagged with both `@task` and `:work:`

#### Scenario: Test inbox has bare task headline
- **WHEN** the test inbox is parsed
- **THEN** one headline MUST be tagged with `@task` only (no secondary tag)

#### Scenario: Test inbox has multi-line body
- **WHEN** the test inbox is parsed
- **THEN** the third headline MUST have a body with multi-line text below it to exercise body extraction

#### Scenario: Test inbox has unique titles
- **WHEN** the test inbox is parsed
- **THEN** each headline title MUST be unique enough that grep assertions are unambiguous
- **AND** no headline title SHALL be a single common word like "Test"

#### Scenario: Test inbox has no link headlines
- **WHEN** the test inbox is loaded
- **THEN** it MUST NOT contain any headlines tagged with `@link`