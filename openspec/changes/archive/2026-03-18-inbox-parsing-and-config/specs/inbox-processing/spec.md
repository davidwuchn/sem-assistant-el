## MODIFIED Requirements

### Requirement: Headlines parsed with org-element including body
The function `sem-router--parse-headlines` SHALL use `org-element-parse-buffer` and `org-element-map` over `headline` type elements instead of regex. It SHALL return the same plist shape as before plus a `:body` key. Tags SHALL be extracted via `org-element-property :tags`. Title SHALL be extracted via `org-element-property :raw-value`. Body SHALL be extracted as the concatenated text of all non-headline child elements of the headline, trimmed.

#### Scenario: Headline parsed with org-element
- **WHEN` `sem-router--parse-headlines` processes an Org buffer
- **THEN** it uses `org-element-parse-buffer` to get the AST
- **AND** it uses `org-element-map` with type `'headline` to iterate

#### Scenario: Plist includes body key
- **WHEN** `sem-router--parse-headlines` returns headline plists
- **THEN** each plist contains `:title`, `:tags`, `:body`, `:point`, and `:hash` keys

#### Scenario: Tags extracted without colons
- **WHEN** parsing a headline with tags `:tag1:tag2:`
- **THEN** the `:tags` value is a list of strings `("tag1" "tag2")` without colons

#### Scenario: Hash includes body in computation
- **WHEN** computing the hash for a headline
- **THEN** the formula is `(secure-hash 'sha256 (concat title "|" (or tags-str "") "|" (or body "")))`

## ADDED Requirements

### Requirement: README documents Orgzly sync timing warning
The README SHALL contain a **WARNING** section immediately after the "Scheduled Tasks" table titled "Orgzly Sync Timing". The section SHALL warn users that Orgzly must not sync during specific windows to prevent data loss.

#### Scenario: Warning section present in README
- **WHEN** viewing the README after the "Scheduled Tasks" table
- **THEN** a "WARNING: Orgzly Sync Timing" section is present

#### Scenario: Warning specifies unsafe windows
- **WHEN** reading the Orgzly Sync Timing warning
- **THEN** it specifies windows `XX:28–XX:32` and `XX:58–XX:02` (every hour)
- **AND** it specifies window `04:00–04:05` (purge window)

#### Scenario: Warning explains reason
- **WHEN** reading the Orgzly Sync Timing warning
- **THEN** it explains that concurrent writes cause silent data loss due to non-atomic read-modify-write operations
