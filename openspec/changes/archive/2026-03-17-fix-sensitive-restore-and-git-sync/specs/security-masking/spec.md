## MODIFIED Requirements

### Requirement: Tokens restored in output before writing
The system SHALL restore original sensitive content from the token map after receiving LLM output and before writing to disk. The detokenization SHALL use the same token map from the input phase. For `sem-url-capture-process`, `sem-security-restore-from-llm` SHALL be called on the raw LLM response string, using the `:security-blocks` from context, before passing the result to `sem-url-capture--validate-and-save`.

#### Scenario: Tokens restored after LLM response
- **WHEN** LLM output contains `{{SEC_ID_xxx}}` or `<<SENSITIVE_xxx>>` tokens
- **THEN** tokens are replaced with original sensitive content before writing

#### Scenario: Round-trip preserves original
- **WHEN** content is tokenized, sent to LLM, and detokenized
- **THEN** the original sensitive text appears unchanged in the output

#### Scenario: restore-from-llm called before validate-and-save in url-capture
- **WHEN** `sem-url-capture-process` receives LLM response
- **THEN** `sem-security-restore-from-llm` is called before `sem-url-capture--validate-and-save`
- **AND** the `blocks` argument is `(plist-get context :security-blocks)`

## REMOVED Requirements

### Requirement: Tokens restored in output before writing (previous version)
**Reason**: The requirement incorrectly stated that `sem-security-restore-from-llm` SHALL NOT be called in `sem-url-capture-process`. This was a bug that caused sensitive content to be lost. The requirement has been corrected to mandate calling `sem-security-restore-from-llm`.

**Migration**: The corrected requirement is now in the MODIFIED Requirements section above.
