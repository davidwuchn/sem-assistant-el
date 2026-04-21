## Purpose

This capability defines deterministic extraction and normalization of mention metadata from journal body text.

## Requirements

### Requirement: Mentions are extracted using deterministic token matching
The system SHALL extract mentions from journal body text using tokens matching `@[A-Za-z0-9_-]+` and stop parsing each token at the first invalid character.

#### Scenario: Mention token parsed before punctuation
- **WHEN** the body contains `@wife,`
- **THEN** extracted mention value includes `wife`

#### Scenario: Mention token parsed before invalid symbol
- **WHEN** the body contains `@some!`
- **THEN** extracted mention value includes `some`

### Requirement: Mention metadata stores normalized deduplicated values
The system SHALL store `MENTIONS_RAW` as comma-separated mention values without leading `@`, deduplicated in first-seen order.

#### Scenario: Duplicate mentions keep first-seen order
- **WHEN** the body contains `@boss ... @wife ... @boss`
- **THEN** `MENTIONS_RAW` is `boss, wife`
