## MODIFIED Requirements

### Requirement: Sensitive blocks replaced with tokens before LLM call
The system SHALL replace all `#+begin_sensitive` / `#+end_sensitive` blocks with opaque tokens before any content is sent to the LLM API. The original text SHALL be stored in a token map for restoration. The function `sem-security-sanitize-for-llm` SHALL be called in `sem-url-capture-process` on the sanitized article text before passing it to `sem-llm-request`. The returned `blocks` alist SHALL be stored in the context plist under `:security-blocks`.

#### Scenario: Sensitive content tokenized in url-capture
- **WHEN** `sem-url-capture-process` processes content with `#+begin_sensitive...#+end_sensitive` blocks
- **THEN** `sem-security-sanitize-for-llm` is called before `sem-llm-request`

#### Scenario: Security blocks stored in context
- **WHEN** content is tokenized for url-capture
- **THEN** the blocks alist is stored in the context plist under `:security-blocks`

### Requirement: Tokens restored in output before writing
The system SHALL restore original sensitive content from the token map after receiving LLM output and before writing to disk. The detokenization SHALL use the same token map from the input phase. For `sem-url-capture-process`, `sem-security-restore-from-llm` SHALL NOT be called because LLM output is a new org document, not a transformed version of the input.

#### Scenario: restore-from-llm NOT called in url-capture
- **WHEN** `sem-url-capture-process` receives LLM response
- **THEN** `sem-security-restore-from-llm` is explicitly NOT called

### Requirement: URL sanitization for url-capture output
The system SHALL sanitize URLs in `/data/org-roam/` output by replacing `http://` with `hxxp://` and `https://` with `hxxps://`. The function `sem-security-sanitize-urls` SHALL be applied to the raw LLM response string in `sem-url-capture-process` before it is passed to `sem-url-capture--validate-and-save`.

#### Scenario: URLs sanitized before validate-and-save
- **WHEN** `sem-url-capture-process` receives raw LLM response
- **THEN** `sem-security-sanitize-urls` is called on the response before `sem-url-capture--validate-and-save`

#### Scenario: Real URLs preserved in org-roam (url-capture excluded from defanging)
- **WHEN** url-capture writes to `/data/org-roam/`
- **THEN** URLs are sanitized (defanged) by `sem-security-sanitize-urls` before write

**Note:** The original requirement "URL sanitization excluded from url-capture output" is REPLACED by this modified requirement. URL sanitization IS now applied in url-capture, but the sanitized URLs are still valid for org-roam use (hxxp:// is a safe reference format).
