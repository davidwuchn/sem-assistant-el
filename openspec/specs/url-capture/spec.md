## Purpose

This capability defines the URL capture pipeline that fetches articles via trafilatura, generates org-roam nodes via LLM, and saves them to the org-roam directory.

## ADDED Requirements

### Requirement: URL sanitization not applied to org-roam output
The system SHALL NOT apply URL sanitization (defanging) to url-capture org-roam output. org-roam requires real URLs for proper link resolution and backlink functionality.

#### Scenario: Real URLs preserved in org-roam
- **WHEN** url-capture writes an org-roam node to `/data/org-roam/`
- **THEN** URLs remain in their original `http://` or `https://` format

#### Scenario: URL sanitization excluded from url-capture
- **WHEN** `sem-url-capture-process` generates org-roam output
- **THEN** `sem-security-sanitize-urls` is NOT called on the output

## Requirements

### Requirement: url-capture pipeline triggered by inbox-processing
The system SHALL provide `sem-url-capture-process` as a non-interactive function callable from `sem-router.el`. The function SHALL accept a URL and headline metadata, run the full capture pipeline, and return the saved filepath on success or `nil` on failure.

#### Scenario: url-capture called with valid URL
- **WHEN** `sem-router.el` calls `sem-url-capture-process` with a URL from a `:link:` headline
- **THEN** the full pipeline executes: fetch, sanitize, query umbrella nodes, LLM, validate, save

#### Scenario: Success returns filepath
- **WHEN** the pipeline completes successfully
- **THEN** `sem-url-capture-process` returns the absolute filepath of the saved org-roam node

#### Scenario: Failure returns nil
- **WHEN** any step in the pipeline fails (trafilatura error, LLM error, validation failure)
- **THEN** `sem-url-capture-process` returns `nil`

### Requirement: trafilatura installed in Emacs container
The system SHALL have the `trafilatura` Python package installed in the Emacs container. The Dockerfile SHALL declare this dependency. `sem-url-capture--fetch-url` SHALL verify trafilatura is available via `executable-find`.

#### Scenario: trafilatura executable found
- **WHEN** the Emacs container starts
- **THEN** `executable-find` returns the path to the `trafilatura` CLI

#### Scenario: Missing trafilatura causes build failure
- **WHEN** the Dockerfile is built without trafilatura installation
- **THEN** the build fails or the daemon logs an error at startup

### Requirement: trafilatura fetches and extracts article text
The system SHALL call `trafilatura` CLI to fetch the full article text from the provided URL. The output SHALL be captured and passed to the sanitization step.

#### Scenario: Article text fetched successfully
- **WHEN** `trafilatura` is called with a valid article URL
- **THEN** the full article text is returned with HTML stripped

#### Scenario: Invalid URL handled gracefully
- **WHEN** `trafilatura` is called with an unreachable or invalid URL
- **THEN** trafilatura exits non-zero and the error is logged

### Requirement: trafilatura errors logged and return nil
The system SHALL handle trafilatura failures (non-zero exit code, empty content). The error SHALL be appended to `/data/errors.org` and the function SHALL return `nil`.

#### Scenario: Non-zero exit code logged
- **WHEN** `trafilatura` exits with code 1 or higher
- **THEN** the error is appended to `/data/errors.org` and `nil` is returned

#### Scenario: Empty content logged
- **WHEN** `trafilatura` returns empty content
- **THEN** the error is appended to `/data/errors.org` and `nil` is returned

### Requirement: Content truncation limit configured via env var
The system SHALL read `URL_CAPTURE_MAX_CHARS` from the environment to determine the maximum character count for sanitized article content passed to the LLM. The default value SHALL be `200000` if unset. This is a separate variable from `RSS_MAX_INPUT_CHARS` and SHALL NOT be shared.

### Requirement: Content sanitized for token efficiency
The system SHALL sanitize fetched content before sending to the LLM. Sanitization SHALL remove digit-only lines, single-character lines, collapse excessive whitespace, and truncate to the configured maximum (`URL_CAPTURE_MAX_CHARS` or default).

#### Scenario: Digit-only lines removed
- **WHEN** content contains lines with only digits
- **THEN** those lines are removed from the sanitized output

#### Scenario: Excessive whitespace collapsed
- **WHEN** content contains multiple consecutive newlines or spaces
- **THEN** they are collapsed to single whitespace

#### Scenario: Content truncated to max chars
- **WHEN** sanitized content exceeds `URL_CAPTURE_MAX_CHARS`
- **THEN** it is truncated to the limit

### Requirement: org-roam DB queried for umbrella nodes
The system SHALL query the org-roam database to find existing umbrella nodes matching the article's topic. The query SHALL use tags or keywords to find relevant parent nodes for linking.

#### Scenario: Umbrella nodes found
- **WHEN** the org-roam DB contains nodes with matching tags
- **THEN** those nodes are returned for inclusion in the LLM prompt

#### Scenario: No umbrella nodes found
- **WHEN** no matching nodes exist in the org-roam DB
- **THEN** the pipeline continues without umbrella node suggestions

### Requirement: LLM generates structured org-roam node
The system SHALL send the sanitized content and umbrella node context to the LLM. The LLM SHALL return a structured org-roam node with `:PROPERTIES:`, `:ID:`, `#+title:`, `#+ROAM_REFS:`, and content sections. When umbrella node context is provided, generated output SHALL include at least one explicit org link to a relevant umbrella node ID.

#### Scenario: Valid org-roam node generated
- **WHEN** the LLM receives valid input
- **THEN** it returns a properly formatted org-roam node with all required fields

#### Scenario: Umbrella node linked when umbrella context exists
- **WHEN** umbrella node candidates are provided to URL-capture generation
- **THEN** the generated output MUST include at least one `[[id:<umbrella-id>][...]]` link to a provided umbrella node

#### Scenario: Trusted integration fixture link is supported
- **WHEN** trusted URL-capture integration runs provide umbrella fixture ID `96a58b04-1f58-47c9-993f-551994939252`
- **THEN** at least one generated candidate node MUST be able to include `[[id:96a58b04-1f58-47c9-993f-551994939252][...]]` so integration assertions can verify graph linkage

### Requirement: Sensitive blocks restored before saving
The system SHALL restore sensitive content blocks into the LLM response before saving to the org-roam node. `sem-security-sanitize-for-llm` returns a three-element list `(tokenized-text blocks-alist position-info-alist)`. The `blocks-alist` (second element) SHALL be stored in the context plist under `:security-blocks`. After receiving a non-nil LLM response, `sem-security-restore-from-llm` SHALL be called on the raw LLM response string using the `:security-blocks` from context, before passing the result to `sem-url-capture--validate-and-save`. Tokens in the LLM response that have no corresponding entry in `security-blocks` SHALL be left as-is. If `security-blocks` is nil or empty, the call to `sem-security-restore-from-llm` SHALL still be made and SHALL return the text unchanged.

#### Scenario: Sensitive blocks restored in url-capture
- **WHEN** `sem-url-capture-process` receives a non-nil LLM response
- **THEN** `sem-security-restore-from-llm` is called on the raw response using `:security-blocks` from context
- **AND** the restored content is passed to `sem-url-capture--validate-and-save`

#### Scenario: Unknown tokens left unchanged
- **WHEN** the LLM response contains a `<<SENSITIVE_xxx>>` token not present in `security-blocks`
- **THEN** the token is left as-is in the output (no error, no crash)

#### Scenario: Empty security-blocks handled gracefully
- **WHEN** `security-blocks` is nil or empty
- **THEN** `sem-security-restore-from-llm` is still called and returns the text unchanged

### Requirement: LLM output validated before saving
The system SHALL validate LLM output before writing to disk. Validation SHALL check for presence of `:PROPERTIES:`, `:ID:`, and `#+title:`. Invalid output SHALL be sent to `/data/errors.org`.

#### Scenario: Valid output passes validation
- **WHEN** LLM output contains `:PROPERTIES:`, `:ID:`, and `#+title:`
- **THEN** the output is saved to `/data/org-roam/`

#### Scenario: Missing :PROPERTIES: fails validation
- **WHEN** LLM output lacks `:PROPERTIES:` block
- **THEN** the output is sent to `/data/errors.org` and `nil` is returned

#### Scenario: Missing :ID: fails validation
- **WHEN** LLM output lacks `:ID:` in properties
- **THEN** the output is sent to `/data/errors.org` and `nil` is returned

#### Scenario: Missing #+title: fails validation
- **WHEN** LLM output lacks `#+title:` line
- **THEN** the output is sent to `/data/errors.org` and `nil` is returned

### Requirement: org-roam-db-sync called after successful save
The system SHALL call `org-roam-db-sync` after each successful node file write. This ensures the new node is immediately indexed and discoverable.

#### Scenario: DB synced after save
- **WHEN** a new org-roam node is successfully written to `/data/org-roam/`
- **THEN** `org-roam-db-sync` is called to index the new node

### Requirement: org-roam directory hardcoded
The system SHALL use `/data/org-roam/` as the org-roam directory. This path SHALL be hardcoded in `init.el`, not configurable at runtime.

#### Scenario: org-roam uses hardcoded path
- **WHEN** the daemon starts
- **THEN** `org-roam-directory` is set to `/data/org-roam/` from `init.el`

### Requirement: Source URL visible in Summary section
The system SHALL write the source URL as the first line of the `* Summary` section body as a plain org-mode link: `Source: [[URL][URL]]`. This ensures visibility in org-roam-ui's node preview. `#+ROAM_REFS` SHALL still be written for backlink resolution but is not the primary display mechanism.

#### Scenario: Source URL in Summary
- **WHEN** an org-roam node is generated
- **THEN** the first line of `* Summary` is `Source: [[URL][URL]]`

#### Scenario: #+ROAM_REFS still written
- **WHEN** an org-roam node is generated
- **THEN** `#+ROAM_REFS: URL` is included in the file for org-roam backlink resolution

### Requirement: Headline marked processed after url-capture invoked
The system SHALL implement bounded retry for URL capture failures. When `sem-url-capture-process` returns `nil` (indicating trafilatura or LLM failure), the router SHALL increment a retry counter for that headline. After 3 cumulative failures, the headline SHALL be moved to DLQ. Before 3 failures, the headline SHALL remain unprocessed for retry on the next cron cycle.

#### Scenario: First failure increments retry counter
- **WHEN** `sem-url-capture-process` returns `nil` for a headline
- **THEN** the retry counter for that headline hash is incremented to 1
- **AND** the headline is NOT marked as processed

#### Scenario: Second failure increments retry counter
- **WHEN** `sem-url-capture-process` returns `nil` for a headline with retry count 1
- **THEN** the retry counter is incremented to 2
- **AND** the headline is NOT marked as processed

#### Scenario: Third failure moves to DLQ
- **WHEN** `sem-url-capture-process` returns `nil` for a headline with retry count 2
- **THEN** the headline is moved to DLQ via `sem-core--mark-dlq`
- **AND** the headline is marked as processed
- **AND** the retry counter is cleared

#### Scenario: Success clears retry counter
- **WHEN** `sem-url-capture-process` returns a filepath for a headline with retry count > 0
- **THEN** the retry counter is cleared
- **AND** the headline is marked as processed

#### Scenario: Failure NOT marked processed (retryable)
- **WHEN** `sem-url-capture-process` returns `nil` and retry count < 3
- **THEN** the headline hash is NOT added to `.sem-cursor.el`
- **AND** the headline will be retried on next cron run

#### Scenario: Failure marked processed (DLQ)
- **WHEN** `sem-url-capture-process` returns `nil` and retry count reaches 3
- **THEN** the headline hash IS added to `.sem-cursor.el`
- **AND** the headline is moved to `/data/errors.org`

### Requirement: Retry counter uses headline content hash
The system SHALL use the headline content hash as the retry counter key. The key format SHALL match the existing `:task:` retry key format.

#### Scenario: Same headline content same key
- **WHEN** two headlines have identical content
- **THEN** they share the same retry counter key

#### Scenario: Different headline content different key
- **WHEN** two headlines have different content
- **THEN** they have different retry counter keys

### Requirement: DLQ escalation writes to errors.org and logs
The system SHALL write DLQ-escalated headlines to `/data/errors.org` and log to `sem-log.org` with status DLQ when a URL capture reaches 3 failures.

#### Scenario: DLQ write on third failure
- **WHEN** a headline reaches 3 URL capture failures
- **THEN** the headline is appended to `/data/errors.org`
- **AND** an entry is written to `sem-log.org` with status DLQ
