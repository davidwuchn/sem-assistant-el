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

### Requirement: No sensitive content reaches LLM API
The system SHALL ensure that no content between `#+begin_sensitive` and `#+end_sensitive` markers is ever transmitted to the LLM API. This is a hard requirement.

#### Scenario: Tokenized content sent to LLM
- **WHEN** content with sensitive blocks is prepared for LLM
- **THEN** only tokens (not original sensitive text) are in the request

### Requirement: Token expansion detection
The system SHALL detect when an LLM output contains actual secret content instead of tokens. This SHALL be treated as a CRITICAL security incident indicating sanitizer failure.

#### Scenario: Expansion detected in LLM output
- **WHEN** LLM output contains original sensitive content from blocks-alist
- **THEN** expansion is flagged
- **AND** the response is rejected (not written to tasks.org)
- **AND** a CRITICAL error is logged

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
