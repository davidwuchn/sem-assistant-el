## MODIFIED Requirements

### Requirement: Sensitive blocks restored before saving
The system SHALL restore sensitive content blocks into the LLM response before saving to the org-roam node. After receiving a non-nil LLM response, `sem-security-restore-from-llm` SHALL be called on the raw LLM response string using the `security-blocks` alist from the context plist (under `:security-blocks`), before passing the result to `sem-url-capture--validate-and-save`. Tokens in the LLM response that have no corresponding entry in `security-blocks` SHALL be left as-is. If `security-blocks` is nil or empty, the call to `sem-security-restore-from-llm` SHALL still be made and SHALL return the text unchanged.

#### Scenario: Sensitive blocks restored in url-capture
- **WHEN** `sem-url-capture-process` receives a non-nil LLM response
- **THEN** `sem-security-restore-from-llm` is called on the raw response using `:security-blocks` from context
- **AND** the restored content is passed to `sem-url-capture--validate-and-save`

#### Scenario: Unknown tokens left unchanged
- **WHEN** the LLM response contains a `<<SENSITIVE_xxx>>` token not present in `security-blocks`
- **THEN** the token is left as-is in the output (no error, no crash)

#### Scenario: Empty security-blocks handled gracefully
- **WHEN** `security-blocks` is nil or empty
- **THEN** `sem-security-restore-from-llm` is still called and returns the text unchanged
