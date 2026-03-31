## MODIFIED Requirements

### Requirement: Token expansion detection
The system SHALL detect when an LLM output contains actual secret content instead of tokens. This SHALL be treated as a CRITICAL security incident indicating sanitizer failure. In `sem-router--route-to-task-llm`, the callback SHALL call `sem-security-verify-tokens-present` on the raw LLM response before restoration. If the returned `expanded` list is non-empty, the response SHALL be rejected (not written to tasks output), a CRITICAL entry SHALL be written to `/data/errors.org` via `sem-core-log-error`, and the headline SHALL be marked processed to prevent infinite retry with the same leaked content.

#### Scenario: Expansion detected in task-router callback
- **WHEN** `sem-router--route-to-task-llm` callback receives raw LLM output containing original sensitive content from `blocks-alist`
- **THEN** `sem-security-verify-tokens-present` flags expansion before restoration
- **AND** the response is rejected (not written to tasks.org)
- **AND** a CRITICAL error is logged
- **AND** the headline hash is recorded as processed

#### Scenario: Missing tokens do not trigger expansion rejection
- **WHEN** the LLM omits or drops one or more expected tokens but does not include expanded sensitive plaintext
- **THEN** expansion rejection is not triggered solely for missing tokens

#### Scenario: Verification order is enforced before restoration
- **WHEN** task-router callback handles a successful LLM response
- **THEN** `sem-security-verify-tokens-present` is called on raw output before `sem-security-restore-from-llm`
