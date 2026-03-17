## ADDED Requirements

### Requirement: Unit test for sem-security-restore-from-llm
The system SHALL provide an ERT test that verifies `sem-security-restore-from-llm` correctly restores sensitive block content from tokens. The test SHALL be located in `app/elisp/tests/sem-url-capture-test.el`.

#### Scenario: Token replaced with sensitive content
- **WHEN** calling `sem-security-restore-from-llm` with a raw LLM response containing `<<SENSITIVE_1>>`
- **AND** the `security-blocks` alist contains `("<<SENSITIVE_1>>" . "#+begin_sensitive\nSECRET\n#+end_sensitive")`
- **THEN** the returned string contains `SECRET`
- **AND** the returned string does NOT contain `<<SENSITIVE_1>>`

#### Scenario: Multiple tokens restored
- **WHEN** calling `sem-security-restore-from-llm` with multiple different sensitive tokens
- **AND** the `security-blocks` alist contains entries for all tokens
- **THEN** all tokens are replaced with their corresponding sensitive content
