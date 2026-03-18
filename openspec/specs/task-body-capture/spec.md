## Purpose

This capability defines the org-element based headline parsing system that captures body content from Org headlines.

## Requirements

### Requirement: Headlines parsed with org-element to capture body content
The system SHALL parse Org headlines using `org-element-parse-buffer` and `org-element-map` instead of regex. Each headline SHALL be converted to a plist containing `:title`, `:tags`, `:body`, `:point`, and `:hash` keys. The `:body` key SHALL contain the raw text of all content between the headline line and the next sibling or parent headline, with leading and trailing whitespace stripped. If the headline has no body content, `:body` SHALL be `nil`.

#### Scenario: Headline with body content
- **WHEN** parsing an Org file containing `* Headline title :tag:\nBody text here\n* Next headline`
- **THEN** the returned plist contains `:body` with value `"Body text here"`

#### Scenario: Headline without body content
- **WHEN** parsing an Org file containing `* Headline title :tag:\n* Next headline`
- **THEN** the returned plist contains `:body` with value `nil`

#### Scenario: Nested sub-headlines excluded from body
- **WHEN** parsing an Org file containing `* Parent :tag:\nParent body\n** Child :child:\nChild body`
- **THEN** the parent's `:body` contains only `"Parent body"` and excludes the child headline and its content

#### Scenario: Body includes paragraphs and lists
- **WHEN** parsing an Org file containing `* Task :@task:\n- Item 1\n- Item 2\n\nParagraph text`
- **THEN** the returned plist contains `:body` with the combined list and paragraph text

#### Scenario: Body excludes property drawers and planning lines
- **WHEN** parsing an Org file containing `* Task :@task:\n:PROPERTIES:\n:ID: abc\n:END:\nBody text`
- **THEN** the property drawer content is handled correctly and `:body` contains `"Body text"`

### Requirement: Hash computation includes body content
The system SHALL compute headline hashes using SHA256 of the concatenation: `title + "|" + tags + "|" + body`, where empty or nil body is treated as empty string. Tags SHALL be concatenated without colons and separated by spaces.

#### Scenario: Hash with body content
- **WHEN** computing hash for a headline with title `"Task"`, tags `"work"`, and body `"Description here"`
- **THEN** the hash equals `(secure-hash 'sha256 "Task|work|Description here")`

#### Scenario: Hash with nil body
- **WHEN** computing hash for a headline with title `"Task"`, tags `"work"`, and body `nil`
- **THEN** the hash equals `(secure-hash 'sha256 "Task|work|")`

#### Scenario: Hash with empty tags
- **WHEN** computing hash for a headline with title `"Task"`, tags `nil`, and body `"Description"`
- **THEN** the hash equals `(secure-hash 'sha256 "Task||Description")`
