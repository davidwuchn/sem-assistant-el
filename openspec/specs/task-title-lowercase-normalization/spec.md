## Purpose

This capability defines normalization behavior for generated `:task:` headline titles before they are written to destination Org files.

## Requirements

### Requirement: Generated task titles are normalized to lowercase before write
The system SHALL normalize generated `:task:` headline titles to lowercase after task-response validation and before writing to destination Org files.

#### Scenario: Mixed-case task title is normalized
- **WHEN** a validated task entry contains a mixed-case title
- **THEN** the persisted headline title is lowercase

#### Scenario: Priority marker is preserved during normalization
- **WHEN** a validated task headline includes an Org priority marker such as `[#A]`
- **THEN** the priority marker remains unchanged and only the title text is lowercased

#### Scenario: Normalization is idempotent across retries
- **WHEN** lowercase normalization is applied to a title that is already lowercase
- **THEN** the resulting headline remains unchanged

#### Scenario: Non-title task content is preserved
- **WHEN** lowercase normalization runs on a validated task entry
- **THEN** body text, metadata drawers, IDs, and scheduling/deadline lines remain unchanged
