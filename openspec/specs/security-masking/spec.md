## Purpose

This capability defines the security masking system that protects sensitive content from being exposed to the LLM API and sanitizes URLs in appropriate outputs.

## Requirements

### Requirement: Sensitive blocks replaced with tokens before LLM call
The system SHALL replace all `#+begin_sensitive` / `#+end_sensitive` blocks with opaque tokens before any content is sent to the LLM API. The original text SHALL be stored in a token map for restoration. The function `sem-security-sanitize-for-llm` SHALL return a three-element list: `(tokenized-text blocks-alist position-info-alist)`. The function SHALL be called in `sem-url-capture-process` on the sanitized article text before passing it to `sem-llm-request`. The returned `blocks-alist` SHALL be stored in the context plist under `:security-blocks`.

#### Scenario: Sensitive content tokenized
- **WHEN** content contains `#+begin_sensitive...#+end_sensitive` blocks
- **THEN** the sensitive content is replaced with `<<SENSITIVE_xxx>>` tokens

#### Scenario: Original content preserved in token map
- **WHEN** content is tokenized
- **THEN** the original sensitive text is stored in a map keyed by token

#### Scenario: Sensitive content tokenized in url-capture
- **WHEN** `sem-url-capture-process` processes content with `#+begin_sensitive...#+end_sensitive` blocks
- **THEN** `sem-security-sanitize-for-llm` is called before `sem-llm-request`

#### Scenario: Security blocks stored in context
- **WHEN** content is tokenized for url-capture
- **THEN** the blocks alist is stored in the context plist under `:security-blocks`

#### Scenario: Sanitize returns three-element list
- **WHEN** `sem-security-sanitize-for-llm` is called
- **THEN** it returns a list of three elements: `(tokenized-text blocks-alist position-info-alist)`
- **AND** `tokenized-text` is the body with sensitive content replaced by tokens
- **AND** `blocks-alist` maps tokens to original content
- **AND** `position-info-alist` maps tokens to `(before-context . after-context)` pairs

#### Scenario: Position info captured for each block
- **WHEN** content contains multiple sensitive blocks
- **THEN** each block contributes an entry to position-info-alist
- **AND** each entry contains up to 20 chars of surrounding context

### Requirement: Tokens restored in output before writing
The system SHALL restore original sensitive content from the token map after receiving LLM output and before writing to disk. The detokenization SHALL use the same token map from the input phase. For `sem-url-capture-process`, `sem-security-restore-from-llm` SHALL be called on the raw LLM response string, using the `:security-blocks` from context, before passing the result to `sem-url-capture--validate-and-save`.

Sensitive content SHALL be restored as plain text without any block markers. Multi-line content SHALL be indented by 2 spaces per line with a leading newline before content and trailing newline after content. One-line content SHALL be placed at the token position verbatim. After successful restoration and write, the blocks-alist SHALL be cleared to avoid stale data.

#### Scenario: Tokens restored as plain text after LLM response
- **WHEN** LLM output contains `{{SEC_ID_xxx}}` or `<<SENSITIVE_xxx>>` tokens
- **THEN** tokens are replaced with original sensitive content as plain text
- **AND** no `#begin_sensitive` / `#end_sensitive` markers are present in output

#### Scenario: Multi-line content indented correctly
- **WHEN** original sensitive content spans multiple lines
- **THEN** each line is indented by 2 spaces
- **AND** a leading newline precedes the content
- **AND** a trailing newline follows the content

#### Scenario: Single-line content placed verbatim at token position
- **WHEN** original sensitive content is a single line
- **THEN** the content is placed at the token position without indentation or surrounding newlines

#### Scenario: Round-trip preserves original text
- **WHEN** content is tokenized, sent to LLM, and detokenized
- **THEN** the original sensitive text appears unchanged in the output

#### Scenario: restore-from-llm called before validate-and-save in url-capture
- **WHEN** `sem-url-capture-process` receives LLM response
- **THEN** `sem-security-restore-from-llm` is called before `sem-url-capture--validate-and-save`
- **AND** the `blocks` argument is `(plist-get context :security-blocks)`

#### Scenario: blocks-alist cleared after successful write
- **WHEN** sensitive content is restored and written to disk
- **THEN** the blocks-alist is cleared to avoid stale data

### Requirement: No sensitive content reaches LLM API
The system SHALL ensure that no content between `#+begin_sensitive` and `#+end_sensitive` markers is ever transmitted to the LLM API. This is a hard requirement.

#### Scenario: Tokenized content sent to LLM
- **WHEN** content with sensitive blocks is prepared for LLM
- **THEN** only tokens (not original sensitive text) are in the request

### Requirement: Token expansion detection
The system SHALL detect when an LLM output contains actual secret content instead of tokens. This SHALL be treated as a CRITICAL security incident indicating sanitizer failure. In `sem-router--route-to-task-llm`, the callback SHALL call `sem-security-verify-tokens-present` on the raw LLM response before restoration. If the returned `expanded` list is non-empty, the response SHALL be rejected (not written to tasks output), a CRITICAL entry SHALL be written to `/data/errors.org` via `sem-core-log-error`, and the headline SHALL be marked processed to prevent infinite retry with the same leaked content.

#### Scenario: Expansion detected in task-router callback
- **WHEN** `sem-router--route-to-task-llm` callback receives raw LLM output containing original sensitive content from `blocks-alist`
- **THEN** `sem-security-verify-tokens-present` flags expansion before restoration
- **AND** the response is rejected (not written to tasks.org)
- **AND** a CRITICAL error is logged

#### Scenario: Missing tokens do not trigger expansion rejection
- **WHEN** the LLM omits or drops one or more expected tokens but does not include expanded sensitive plaintext
- **THEN** expansion rejection is not triggered solely for missing tokens

#### Scenario: Verification order is enforced before restoration
- **WHEN** task-router callback handles a successful LLM response
- **THEN** `sem-security-verify-tokens-present` is called on raw output before `sem-security-restore-from-llm`

## REMOVED Requirements

### Requirement: URL sanitization for url-capture output
**Reason**: URL sanitization is NOT applied to url-capture output (org-roam). org-roam requires real URLs for link resolution and backlink functionality. URL sanitization is only applied to tasks.org and morning-read outputs.

**Migration**: This requirement is removed. URL sanitization for org-roam (url-capture) output is explicitly excluded.

### Requirement: Local variable blocks disabled
**Reason**: This security requirement is handled by Emacs configuration at the daemon level, not within this capability.

**Migration**: This requirement is removed from security-masking spec.

### Requirement: org-babel evaluation disabled
**Reason**: This security requirement is handled by Emacs configuration at the daemon level, not within this capability.

**Migration**: This requirement is removed from security-masking spec.
