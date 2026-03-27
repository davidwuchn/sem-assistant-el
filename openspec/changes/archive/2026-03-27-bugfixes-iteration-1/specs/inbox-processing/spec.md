## MODIFIED Requirements

### Requirement: Headlines parsed with org-element including body
The function `sem-router--parse-headlines` SHALL use `org-element-parse-buffer` and `org-element-map` over `headline` type elements instead of regex. It SHALL return the same plist shape as before plus a `:body` key. Tags SHALL be extracted via `org-element-property :tags`. Title SHALL be extracted via `org-element-property :raw-value`. Body SHALL be extracted as the concatenated text of all non-headline child elements of the headline, trimmed. Debug logging in this parse path SHALL use numeric position values only and SHALL NOT call numeric operators with marker objects.

#### Scenario: Headline parsed with org-element
- **WHEN** `sem-router--parse-headlines` processes an Org buffer
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

#### Scenario: Debug preview bounds use numeric positions
- **WHEN** `sem-router--parse-headlines` emits debug preview logging
- **THEN** numeric bound expressions use numeric positions (for example `(min (point-max) 100)`)
- **AND** marker objects are not passed to numeric operators such as `min`
