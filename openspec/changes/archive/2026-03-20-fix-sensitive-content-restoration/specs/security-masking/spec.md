## Purpose

This capability defines the security masking system that protects sensitive content from being exposed to the LLM API and sanitizes URLs in appropriate outputs.

## Requirements

### Requirement: Sensitive blocks replaced with tokens before LLM call
The system SHALL replace all `#+begin_sensitive` / `#+end_sensitive` blocks with opaque tokens before any content is sent to the LLM API. The original text SHALL be stored in a token map for restoration. The function `sem-security-sanitize-for-llm` SHALL be called in `sem-url-capture-process` on the sanitized article text before passing it to `sem-llm-request`. The returned `blocks` alist SHALL be stored in the context plist under `:security-blocks`.

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

## MODIFIED Requirements

### Requirement: Sensitive blocks replaced with tokens before LLM call (ENHANCED) — BREAKING CHANGE
The function `sem-security-sanitize-for-llm` SHALL now return a three-element list: `(tokenized-text blocks-alist position-info-alist)`. The position-info-alist SHALL contain context strings for each block for semantic position verification. This is a **BREAKING CHANGE** — all callers MUST be updated to handle the new 3-element return signature.

**Migration for url-capture**: The url-capture pipeline (`sem-url-capture-process`) MUST be updated to destructure the 3-element return and pass the correct elements to `sem-security-restore-from-llm`.

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

## Test Impact (BREAKING CHANGE)

This section defines which existing tests must be updated and which must remain unchanged when implementing the 3-element return signature change.

### Tests that MUST pass unchanged (no modification required)

The following tests verify behavior that is NOT changing and MUST continue to pass after implementation:

**sem-security-test.el — URL sanitization only:**
- `sem-security-test-url-sanitization-http`
- `sem-security-test-url-sanitization-https`
- `sem-security-test-url-sanitization-multiple-urls`
- `sem-security-test-url-sanitization-preservation`
- `sem-security-test-url-sanitization-scope`

**sem-router-test.el — Not affected by security sanitization changes:**
- All parsing, UUID validation, tag normalization, mutex tests

**sem-url-capture-test.el — Not affected by security sanitization return format:**
- Sanitization, slug, validation, URL defanging tests

### Tests that MUST be updated (behavior is changing)

The following tests explicitly depend on the old 2-element return signature `(cons-cell)` and MUST be updated to handle the new 3-element return:

**sem-security-test.el:**
- `sem-security-test-tokenize-detokenize-roundtrip` — Uses `(cdr result)` which with 3-element list returns `(blocks-alist . position-info-alist)` instead of just `blocks-alist`. Must use `(cadr result)` for blocks-alist.
- `sem-security-test-sensitive-content-masked` — Uses `(car result)` which still works for first element; update should verify position-info exists.

**sem-router-test.el:**
- `sem-router-test-security-block-round-trip` — Explicitly tests `(car result)` and `(cdr result)` on 2-element cons. Must update for 3-element destructuring with `(car)`, `(cadr)`, `(caddr)`.
- `sem-router-test-body-nil-skips-sanitization` — Uses `(car result)` and `(cdr result)`; must update destructuring.

**sem-url-capture-test.el:**
- `sem-url-capture-test-security-tokenizes-sensitive-blocks` — Uses `(car result)` and `(cdr result)`. Must use `(cadr result)` for blocks-alist.
- `sem-url-capture-test-restore-from-llm-unit` — May need update if it passes full result instead of just blocks-alist.
- `sem-url-capture-test-restore-integration` — Mock setup passes `:security-blocks` via context plist; likely needs update to the mock's 3-element structure.
