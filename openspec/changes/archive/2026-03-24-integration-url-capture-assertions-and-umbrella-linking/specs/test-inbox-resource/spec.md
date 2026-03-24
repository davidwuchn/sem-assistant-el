# Specification: test-inbox-resource

## MODIFIED Requirements

### Requirement: Test inbox resource file exists
The system SHALL provide a test inbox org file at `dev/integration/testing-resources/inbox-tasks.org` that exercises both the task-processing pipeline and URL-capture inputs for trusted integration coverage.

#### Scenario: Test inbox has at least one task headline
- **WHEN** the test inbox is loaded
- **THEN** it MUST contain at least 1 headline tagged with `:task:`
- **AND** the expected task count is derived dynamically at runtime by counting `^\* TODO .*:task:` lines

#### Scenario: Test inbox has routine-tagged headline
- **WHEN** the test inbox is parsed
- **THEN** one headline MUST be tagged with both `:task:` and `:routine:`

#### Scenario: Test inbox has work-tagged headline
- **WHEN** the test inbox is parsed
- **THEN** one headline MUST be tagged with both `:task:` and `:work:`

#### Scenario: Test inbox has bare task headline
- **WHEN** the test inbox is parsed
- **THEN** one headline MUST be tagged with `:task:` only (no secondary tag)

#### Scenario: Test inbox has multi-line body
- **WHEN** the test inbox is parsed
- **THEN** the third headline MUST have a body with multi-line text below it to exercise body extraction

#### Scenario: Test inbox has unique titles
- **WHEN** the test inbox is parsed
- **THEN** each headline title MUST be unique enough that grep assertions are unambiguous
- **AND** no headline title SHALL be a single common word like `Test`

#### Scenario: Test inbox contains trusted URL-capture input
- **WHEN** the test inbox is loaded for URL-capture integration coverage
- **THEN** it MUST contain at least one headline tagged with `:link:`
- **AND** the headline body or content MUST include `https://semyonsinchenko.github.io/ssinchenko/post/aider_2026_and_other_topics/`
