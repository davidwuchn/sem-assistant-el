# Specification: aggressive-task-body-rewrite

## Purpose

Require Pass 1 `:task:` body transformation to rewrite shorthand or fragmented captures into explicit, actionable task content without changing user intent.

## Requirements

### Requirement: Fragmented captures are rewritten into explicit task bodies
For `:task:` transformation, the system SHALL rewrite fragmented, shorthand, or telegraphic input into clear task body prose that is immediately actionable.

#### Scenario: Shorthand note is expanded to explicit prose
- **WHEN** raw task input uses shorthand fragments or compressed phrasing
- **THEN** the generated task body SHALL be rewritten into complete, explicit task language

### Requirement: Rewritten body preserves inferable task context
The rewritten task body SHALL preserve inferable constraints, participants, deliverable details, and urgency cues present in the raw input.

#### Scenario: Input includes constraints and stakeholders
- **WHEN** raw task input references constraints, people, or expected deliverable
- **THEN** the rewritten body SHALL retain those details in explicit language

### Requirement: Rewrite improves clarity without inventing facts
Pass 1 body rewrite SHALL improve clarity and completeness while preserving original intent and SHALL NOT introduce facts not inferable from the input.

#### Scenario: Ambiguous detail remains non-fabricated
- **WHEN** raw task input omits concrete details needed for full specificity
- **THEN** the rewritten body SHALL remain faithful to the available input and SHALL NOT invent missing facts

### Requirement: Body rewrite is meaningfully transformed
When input is raw or fragmented, Pass 1 transformation SHALL produce a meaningfully rewritten body rather than lightly edited source text.

#### Scenario: Raw prose is not passed through
- **WHEN** raw task input is noisy and minimally structured
- **THEN** the resulting body SHALL be a clear rewrite that improves readability and actionability
