## MODIFIED Requirements

### Requirement: Headline marked processed after url-capture invoked
The system SHALL classify malformed-sensitive preflight failures in URL capture as terminal security failures (`security-malformed`) and SHALL route them directly to DLQ behavior without retry attempts. Retry counting SHALL continue to apply only to retryable URL-capture failures (for example fetch/provider/validation failures).

#### Scenario: Malformed-sensitive preflight is terminal for URL capture
- **WHEN** URL-capture preflight-sensitive sanitization fails due to malformed delimiters
- **THEN** callback context marks failure kind as `security-malformed`
- **AND** the router routes the headline to DLQ without retry

#### Scenario: Malformed-sensitive preflight does not consume retry budget
- **WHEN** URL-capture fails before LLM due to malformed-sensitive delimiters
- **THEN** URL-capture retry counters are not incremented for retry semantics

#### Scenario: Retryable URL-capture failures remain bounded-retry
- **WHEN** URL-capture fails for retryable reasons not classified as malformed-sensitive
- **THEN** bounded retry behavior remains unchanged
