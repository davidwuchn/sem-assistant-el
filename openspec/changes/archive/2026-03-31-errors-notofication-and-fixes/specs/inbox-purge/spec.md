## MODIFIED Requirements

### Requirement: Purge hash computation matches router format
The system SHALL compute headline hashes in `sem-core-purge-inbox` using exactly the same format as `sem-router--parse-headlines`. The hash input SHALL be `(json-encode (vector title space-joined-tags body))`, and the stored digest SHALL be computed as `(secure-hash 'sha256 <that-json-string>)`.

#### Scenario: Hash matches router computation
- **WHEN** `sem-core-purge-inbox` computes a hash for comparison
- **THEN** it uses `(secure-hash 'sha256 (json-encode (vector title space-joined-tags body)))`
- **AND** this matches the hash stored by `sem-router--parse-headlines`

#### Scenario: Tags are space-joined without colons
- **WHEN** a headline has tags `:tag1:tag2:`
- **THEN** the hash input uses `"tag1 tag2"` (space-separated, no colons)

#### Scenario: Body is included in hash
- **WHEN** a headline has body content
- **THEN** the body text is included as the third element of the JSON vector used for hashing
