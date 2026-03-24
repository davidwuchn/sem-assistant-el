# Specification: task-priority-defaulting

## Purpose

Define deterministic priority handling for normalized task output, including safe fallback behavior when Pass 1 omits or returns invalid priority values.

## Requirements

### Requirement: Final normalized task always has priority
The normalization flow SHALL ensure each final TODO entry has exactly one Org priority token, even when Pass 1 omits priority.

#### Scenario: Missing LLM priority defaults safely
- **WHEN** Pass 1 output does not include any priority token
- **THEN** normalization inserts `[#C]` before planner processing
- **AND** final output includes exactly one priority token

#### Scenario: Existing LLM priority is preserved
- **WHEN** Pass 1 output includes one valid priority token
- **THEN** normalization preserves that token
- **AND** no additional priority token is added

### Requirement: Deterministic fallback priority is [#C]
When Pass 1 returns no priority token, normalization SHALL default priority to `[#C]`.

#### Scenario: Absent priority defaults to [#C]
- **WHEN** Pass 1 returns a TODO with no priority token
- **THEN** final normalized TODO includes priority `[#C]`

#### Scenario: Invalid priority falls back safely
- **WHEN** Pass 1 returns an invalid or unsupported priority token
- **THEN** normalization replaces it with `[#C]`

### Requirement: Prompt urgency mapping remains deterministic when priority is present
When Pass 1 does return a priority for inputs containing conflicting urgency markers, mapping SHALL follow strongest-signal-wins precedence (`[#A]` over `[#B]` over `[#C]`).

#### Scenario: High and low urgency cues conflict
- **WHEN** a note contains both a high urgency marker and low urgency phrasing
- **THEN** Pass 1 emits the higher-priority token according to precedence
