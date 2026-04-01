## MODIFIED Requirements

### Requirement: errors.org format
The `/data/errors.org` file SHALL support optional metadata in error headlines for severity and classification. `sem-core-log-error` callers MAY provide metadata containing `:priority` and `:tags`; when present, headline output SHALL include the provided priority token (for example `[#A]`) and Org tags (for example `:security:`) while preserving the existing error body format.

Malformed-sensitive security failures SHALL be written with priority `[#A]` and tag `:security:`.

#### Scenario: Metadata priority and tags appear in error headline
- **WHEN** `sem-core-log-error` is called with metadata `:priority` and `:tags`
- **THEN** the created `errors.org` TODO headline includes the provided priority and tags

#### Scenario: Metadata omission preserves legacy formatting
- **WHEN** `sem-core-log-error` is called without metadata
- **THEN** the created `errors.org` entry uses the legacy headline format without added tags/priority

#### Scenario: Malformed-sensitive uses high-priority security classification
- **WHEN** malformed-sensitive preflight failure is logged
- **THEN** the error headline includes `[#A]` and `:security:`
