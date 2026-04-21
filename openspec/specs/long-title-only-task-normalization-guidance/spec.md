# Specification: long-title-only-task-normalization-guidance

## Purpose

Define Pass 1 guidance for decomposing long title-only task captures into concise TODO titles and informative rewritten bodies while preserving intent.

## Requirements

### Requirement: Pass 1 prompt includes long title-only decomposition guidance
The Pass 1 task prompt SHALL include explicit guidance for long title-only captures that decomposes dense title text into a concise actionable TODO title and an informative rewritten body without changing user intent.

#### Scenario: Long title-only capture is decomposed into title and body
- **WHEN** a raw `:task:` input has a long headline and no body
- **THEN** the generated TODO title MUST be concise and action-oriented
- **AND** the generated body MUST capture inferable constraints and requested outcomes from the original headline

#### Scenario: Headline and body are separated by function
- **WHEN** title-only input contains multiple details such as stakeholders, deadlines, and deliverables
- **THEN** the normalized title MUST keep only the core action
- **AND** details MUST be moved into rewritten body text rather than packed into the title

### Requirement: Pass 1 prompt preserves semantics for title-only edge cases
For long title-only captures, the Pass 1 prompt SHALL preserve operationally important semantics and SHALL define conservative behavior for ambiguous scheduling and already-concise input.

#### Scenario: Urgency and identifiers are preserved without hallucination
- **WHEN** title-only input includes urgency markers and verbatim identifiers such as ticket numbers or phone numbers
- **THEN** normalized output MUST preserve urgency semantics and those identifiers verbatim
- **AND** rewritten body text MUST NOT introduce non-inferable facts

#### Scenario: Ambiguous scheduling remains unscheduled
- **WHEN** title-only input implies timing intent but lacks sufficient date/time confidence
- **THEN** normalized output MUST remain valid without forcing a `SCHEDULED` timestamp

#### Scenario: Already-concise titles are not over-expanded
- **WHEN** title-only input is already concise and atomic
- **THEN** normalization MUST avoid unnecessary body verbosity
- **AND** output MUST remain brief while preserving the original intent
