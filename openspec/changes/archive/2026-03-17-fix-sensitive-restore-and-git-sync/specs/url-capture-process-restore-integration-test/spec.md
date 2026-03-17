## ADDED Requirements

### Requirement: Integration test for url-capture restore pipeline
The system SHALL provide an ERT test that verifies the full `sem-url-capture-process` callback path correctly restores sensitive blocks before saving. The test SHALL be located in `app/elisp/tests/sem-url-capture-test.el`.

#### Scenario: Full pipeline restores sensitive content
- **WHEN** `sem-llm-request` is stubbed to return a response containing `<<SENSITIVE_1>>`
- **AND** `sem-url-capture-process` is called with a pre-populated `:security-blocks` in context
- **AND** the callback path executes
- **THEN** the saved file content contains the restored sensitive block text
- **AND** the saved file content does NOT contain `<<SENSITIVE_1>>`

#### Scenario: Integration test uses real callback flow
- **WHEN** the integration test runs
- **THEN** it exercises the actual LLM callback code path in `sem-url-capture-process`
- **AND** it verifies the call order: restore → validate-and-save
