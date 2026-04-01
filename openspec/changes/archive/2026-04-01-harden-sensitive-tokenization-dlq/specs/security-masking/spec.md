## MODIFIED Requirements

### Requirement: Sensitive blocks replaced with tokens before LLM call
The system SHALL parse sensitive delimiters before any LLM request and SHALL fail closed when delimiter structure is malformed. Delimiter matching SHALL be case-insensitive (`#+begin_sensitive` and `#+BEGIN_SENSITIVE` are both valid) but delimiters MUST appear on standalone lines. The parser SHALL reject malformed forms including missing end marker, end marker without begin marker, nested begin markers, and inline markers embedded in non-delimiter text. On malformed input, sanitization SHALL raise an error and SHALL NOT return tokenized content for LLM transmission.

#### Scenario: Case-insensitive standalone delimiters are accepted
- **WHEN** content contains uppercase or mixed-case standalone sensitive delimiters
- **THEN** sensitive blocks are tokenized successfully

#### Scenario: Inline begin marker is rejected
- **WHEN** content contains `#+begin_sensitive` not on its own line
- **THEN** sanitization fails before any LLM request

#### Scenario: Missing end marker is rejected
- **WHEN** content contains a begin marker without a matching end marker
- **THEN** sanitization fails before any LLM request

#### Scenario: End marker without begin is rejected
- **WHEN** content contains an end marker that is not inside an open sensitive block
- **THEN** sanitization fails before any LLM request

#### Scenario: Nested begin marker is rejected
- **WHEN** content opens a second sensitive block before closing the first
- **THEN** sanitization fails before any LLM request

### Requirement: No sensitive content reaches LLM API
The system SHALL ensure sensitive plaintext never reaches the LLM API. This guarantee SHALL be enforced by preflight-sensitive parsing and tokenization only; malformed delimiter inputs SHALL be rejected as terminal failures before any LLM call is attempted.

#### Scenario: Malformed delimiter prevents LLM call
- **WHEN** preflight-sensitive parsing detects malformed delimiters
- **THEN** no LLM request is issued

## REMOVED Requirements

### Requirement: Token expansion detection
**Reason**: Post-response expansion verification occurs after an LLM request and does not strengthen the fail-closed boundary once strict preflight validation is enforced.

**Migration**: Enforce malformed-sensitive rejection before LLM calls and remove callback-level expansion verification logic and tests.
