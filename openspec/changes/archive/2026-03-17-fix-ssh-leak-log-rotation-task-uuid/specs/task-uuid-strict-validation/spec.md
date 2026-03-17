## ADDED Requirements

### Requirement: Validate task response with injected UUID
`sem-router--validate-task-response` SHALL accept `(response injected-id)` as parameters. The function SHALL extract the `:ID:` value from the response using `re-search-forward "^:ID:[ \t]*\\([^[:space:]\n]+\\)"` and perform `(string= extracted-id injected-id)`.

#### Scenario: Signature accepts injected-id parameter
- **WHEN** `sem-router--validate-task-response` is called
- **THEN** it accepts two parameters: `response` and `injected-id`

#### Scenario: Extract ID from response properties
- **WHEN** the response contains `:ID: abc-123` in the properties drawer
- **THEN** the function extracts `abc-123` as the ID value

#### Scenario: Exact match validation passes
- **WHEN** the extracted ID exactly matches the injected-id
- **THEN** validation returns non-nil (success)

#### Scenario: Mismatch validation fails
- **WHEN** the extracted ID does not match the injected-id
- **THEN** validation returns nil (failure)

#### Scenario: Missing ID causes validation failure
- **WHEN** the response does not contain an `:ID:` field
- **THEN** validation returns nil (failure)

### Requirement: Failed validation sends to DLQ
If validation fails (mismatch or missing ID), the response SHALL be sent to the Dead Letter Queue (DLQ) following the same path as other malformed output.

#### Scenario: Mismatch goes to DLQ
- **WHEN** validation fails due to ID mismatch
- **THEN** the response is appended to `/data/errors.org`
- **AND** the headline hash is marked as processed

#### Scenario: Missing ID goes to DLQ
- **WHEN** validation fails due to missing ID
- **THEN** the response is appended to `/data/errors.org`
- **AND** the headline hash is marked as processed

### Requirement: All callers pass injected UUID
All callers of `sem-router--validate-task-response` SHALL pass the injected UUID as the second parameter.

#### Scenario: Internal call sites updated
- **WHEN** `sem-router--validate-task-response` is called from within `sem-router.el`
- **THEN** the injected UUID is passed as the second argument
