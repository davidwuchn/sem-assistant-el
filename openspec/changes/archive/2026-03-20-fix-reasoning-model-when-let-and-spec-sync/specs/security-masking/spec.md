## MODIFIED Requirements

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
- **WHEN** LLM output contains `<<SENSITIVE_xxx>>` tokens
- **THEN** tokens are replaced with original sensitive content before writing

#### Scenario: Round-trip preserves original
- **WHEN** content is tokenized, sent to LLM, and detokenized
- **THEN** the original sensitive text appears unchanged in the output

#### Scenario: restore-from-llm called before validate-and-save in url-capture
- **WHEN** `sem-url-capture-process` receives LLM response
- **THEN** `sem-security-restore-from-llm` is called before `sem-url-capture--validate-and-save`
- **AND** the `blocks` argument is `(plist-get context :security-blocks)`

## REMOVED Requirements

### Requirement: URL sanitization for url-capture output
**Reason**: URL sanitization is NOT applied to url-capture output (org-roam). org-roam requires real URLs for link resolution and backlink functionality. URL sanitization is only applied to tasks.org and morning-read outputs.

**Migration**: This requirement is removed. URL sanitization for org-roam (url-capture) output is explicitly excluded.

## Unchanged Requirements

### Requirement: No sensitive content reaches LLM API
The system SHALL ensure that no content between `#+begin_sensitive` and `#+end_sensitive` markers is ever transmitted to the LLM API. This is a hard requirement.

#### Scenario: Tokenized content sent to LLM
- **WHEN** content with sensitive blocks is prepared for LLM
- **THEN** only tokens (not original sensitive text) are in the request

### Requirement: Local variable blocks disabled
The system SHALL disable local variable blocks in Org files (`enable-local-variables nil`) to prevent malicious RSS payloads from re-enabling org-babel evaluation.

#### Scenario: Local variables ignored
- **WHEN** an Org file contains a local variables block
- **THEN** Emacs does not evaluate the variables

### Requirement: org-babel evaluation disabled
The system SHALL disable org-babel evaluation (`org-export-babel-evaluate nil`, `org-confirm-babel-evaluate t`) to prevent execution of embedded code blocks in processed content.

#### Scenario: Babel blocks not evaluated
- **WHEN** an Org file contains source blocks
- **THEN** they are not automatically evaluated
