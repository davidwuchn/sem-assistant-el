## ADDED Requirements

### Requirement: Pre-generate UUID before prompt construction
`sem-router--route-to-task-llm` SHALL call `(org-id-new)` to generate a UUID before constructing any prompt string. The UUID SHALL be bound to a `let`-scoped variable `injected-id`.

#### Scenario: UUID generated before prompt
- **WHEN** `sem-router--route-to-task-llm` is called
- **THEN** `(org-id-new)` is called before any prompt string is built
- **AND** the result is bound to `injected-id`

#### Scenario: UUID is valid org-id format
- **WHEN** the UUID is generated
- **THEN** it is a valid UUID string produced by `org-id-new`

### Requirement: Inject UUID into prompt template
The user-prompt template SHALL include the literal string `:ID: <injected-id>` in the required output format block. The system-prompt SHALL include the instruction: `"Use EXACTLY the :ID: value provided in the template below. Do not generate, modify, or substitute it."`

#### Scenario: UUID in user prompt template
- **WHEN** the user prompt is constructed
- **THEN** it contains `:ID: <injected-id>` where `<injected-id>` is the pre-generated UUID

#### Scenario: System prompt instructs verbatim usage
- **WHEN** the system prompt is constructed
- **THEN** it contains explicit instructions to use the provided `:ID:` value verbatim
- **AND** it instructs the LLM not to generate or modify the ID

### Requirement: Pass injected UUID to callback
The `injected-id` SHALL be passed to the LLM callback via the context plist as `:injected-id`.

#### Scenario: Injected ID in callback context
- **WHEN** the LLM callback is invoked
- **THEN** the context plist contains `:injected-id` with the pre-generated UUID
