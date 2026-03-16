## ADDED Requirements

### Requirement: Sensitive blocks replaced with tokens before LLM call
The system SHALL replace all `#+begin_sensitive` / `#+end_sensitive` blocks with opaque tokens before any content is sent to the LLM API. The original text SHALL be stored in a token map for restoration.

#### Scenario: Sensitive content tokenized
- **WHEN** content contains `#+begin_sensitive...#+end_sensitive` blocks
- **THEN** the sensitive content is replaced with `{{SEC_ID_xxx}}` tokens

#### Scenario: Original content preserved in token map
- **WHEN** content is tokenized
- **THEN** the original sensitive text is stored in a map keyed by token

### Requirement: Tokens restored in output before writing
The system SHALL restore original sensitive content from the token map after receiving LLM output and before writing to disk. The detokenization SHALL use the same token map from the input phase.

#### Scenario: Tokens restored after LLM response
- **WHEN** LLM output contains `{{SEC_ID_xxx}}` tokens
- **THEN** tokens are replaced with original sensitive content before writing

#### Scenario: Round-trip preserves original
- **WHEN** content is tokenized, sent to LLM, and detokenized
- **THEN** the original sensitive text appears unchanged in the output

### Requirement: No sensitive content reaches LLM API
The system SHALL ensure that no content between `#+begin_sensitive` and `#+end_sensitive` markers is ever transmitted to the LLM API. This is a hard requirement.

#### Scenario: Tokenized content sent to LLM
- **WHEN** content with sensitive blocks is prepared for LLM
- **THEN** only tokens (not original sensitive text) are in the request

### Requirement: URL sanitization for inbox-processing output
The system SHALL sanitize URLs in `/data/tasks.org` output by replacing `http://` with `hxxp://` and `https://` with `hxxps://`. This applies only to `inbox-processing` output.

#### Scenario: URLs sanitized in tasks.org
- **WHEN** inbox-processing writes to `/data/tasks.org`
- **THEN** all URLs have their scheme defanged (http → hxxp)

### Requirement: URL sanitization for rss-digest output
The system SHALL sanitize URLs in `/data/morning-read/` output by replacing `http://` with `hxxp://` and `https://` with `hxxps://`. This applies only to `rss-digest` output.

#### Scenario: URLs sanitized in morning-read files
- **WHEN** rss-digest writes to `/data/morning-read/`
- **THEN** all URLs have their scheme defanged (http → hxxp)

### Requirement: URL sanitization excluded from url-capture output
The system SHALL NOT sanitize URLs in `/data/org-roam/` output. Real URLs are required for `#+ROAM_REFS` and `[[link]]` anchors in org-roam nodes.

#### Scenario: Real URLs preserved in org-roam
- **WHEN** url-capture writes to `/data/org-roam/`
- **THEN** URLs remain as `http://` and `https://` (not defanged)

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
