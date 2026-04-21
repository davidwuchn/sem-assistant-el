## Purpose

This capability defines date-tree structure and item numbering rules for deterministic appends to `journal.org`.

## Requirements

### Requirement: Journal entries are stored under date-tree headings
The system SHALL organize appended journal entries under `* YYYY`, `** YYYY-MM`, and `*** YYYY-MM-DD` headings in `journal.org`.

#### Scenario: Missing date headings are inserted once
- **WHEN** a batch targets a day whose year, month, or day heading is missing
- **THEN** the system includes each missing heading once in the final append payload

### Requirement: Journal items are numbered sequentially within day heading
For each `*** YYYY-MM-DD` day heading, the system SHALL create journal item headings as `**** N` where `N` increases sequentially from the last existing numeric item for that day.

#### Scenario: Existing day numbering is continued
- **WHEN** `*** YYYY-MM-DD` already contains items `**** 1` and `**** 2`
- **THEN** the next appended item for that day uses heading `**** 3`

#### Scenario: Multiple batch items receive contiguous numbering
- **WHEN** two journal entries are appended to the same day in one batch
- **THEN** their headings are assigned consecutive numbers without gaps
