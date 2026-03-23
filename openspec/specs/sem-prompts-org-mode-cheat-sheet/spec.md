# Sem Prompts Org Mode Cheat Sheet

## Purpose

(TBD)

## ADDED Requirements

### Requirement: sem-prompts-org-mode-cheat-sheet constant exists
The system SHALL provide a `defconst` named `sem-prompts-org-mode-cheat-sheet` in the `sem-prompts.el` module that contains a comprehensive org-mode syntax cheat sheet for LLM system prompts.

#### Scenario: Module provides the constant
- **WHEN** the `sem-prompts.el` module is loaded
- **THEN** the variable `sem-prompts-org-mode-cheat-sheet` SHALL be defined as a string constant

#### Scenario: Module has no runtime dependencies
- **WHEN** `sem-prompts.el` is loaded in a minimal Emacs environment
- **THEN** the module SHALL NOT contain any `(require 'sem-*)` statements
- **AND** the module SHALL contain `(provide 'sem-prompts)`

### Requirement: Cheat sheet covers all basic formatting syntax
The cheat sheet string MUST cover the following org-mode syntax elements:

#### Scenario: Headings
- **WHEN** the cheat sheet is used in an LLM prompt
- **THEN** it SHALL include the syntax for headings using `*` (e.g., `* Heading`)

#### Scenario: Text formatting
- **WHEN** the cheat sheet is used in an LLM prompt
- **THEN** it SHALL include syntax for:
  - Bold: `*...*`
  - Italic: `/.../`
  - Underline: `_..._`
  - Strikethrough: `+...+`
  - Inline code: `=...=` and `~...~`

#### Scenario: Code blocks
- **WHEN** the cheat sheet is used in an LLM prompt
- **THEN** it SHALL include syntax for code blocks using `#+begin_src` / `#+end_src`

#### Scenario: Block elements
- **WHEN** the cheat sheet is used in an LLM prompt
- **THEN** it SHALL include syntax for:
  - Blockquotes: `#+begin_quote` / `#+end_quote`
  - Example blocks: `#+begin_example` / `#+end_example`
  - Verse blocks: `#+begin_verse` / `#+end_verse`

#### Scenario: Lists
- **WHEN** the cheat sheet is used in an LLM prompt
- **THEN** it SHALL include syntax for:
  - Unordered lists: `-` and `+`
  - Ordered lists: `1.` and `1)`
  - Description lists: `- term :: description`

#### Scenario: Tables
- **WHEN** the cheat sheet is used in an LLM prompt
- **THEN** it SHALL include syntax for tables using `| col | col |` with `|-` separator

#### Scenario: Links
- **WHEN** the cheat sheet is used in an LLM prompt
- **THEN** it SHALL include syntax for:
  - Internal links: `[[*heading][desc]]`
  - External links: `[[url][desc]]`
  - ID links: `[[id:UUID][desc]]`
  - File links: `[[file:path][desc]]`

### Requirement: Cheat sheet covers Orgzly URI schemes
The cheat sheet MUST include Orgzly-supported URI schemes as valid link targets.

#### Scenario: Email URI scheme
- **WHEN** the cheat sheet is used in an LLM prompt
- **THEN** it SHALL include `mailto:user@example.com` as a valid link target

#### Scenario: Phone URI scheme
- **WHEN** the cheat sheet is used in an LLM prompt
- **THEN** it SHALL include `tel:1-800-555-0199` as a valid link target

#### Scenario: Geo URI scheme
- **WHEN** the cheat sheet is used in an LLM prompt
- **THEN** it SHALL include:
  - `geo:40.7128,-74.0060`
  - `geo:0,0?q=new+york+city`
  - `geo:40.7128,-74.0060?z=11`

### Requirement: Cheat sheet includes BAD/GOOD callouts
The cheat sheet MUST include explicit callouts for common LLM mistakes with correct alternatives.

#### Scenario: Heading mistakes
- **WHEN** the cheat sheet is used in an LLM prompt
- **THEN** it SHALL include: `# heading` → `* heading`

#### Scenario: Code formatting mistakes
- **WHEN** the cheat sheet is used in an LLM prompt
- **THEN** it SHALL include: `` `code` `` → `=code=`

#### Scenario: Bold formatting mistakes
- **WHEN** the cheat sheet is used in an LLM prompt
- **THEN** it SHALL include: `**bold**` → `*bold*`

#### Scenario: Italic formatting mistakes
- **WHEN** the cheat sheet is used in an LLM prompt
- **THEN** it SHALL include: `*italic*` → `/italic/`

#### Scenario: Quote formatting mistakes
- **WHEN** the cheat sheet is used in an LLM prompt
- **THEN** it SHALL include: `> quote` → `#+begin_quote`

#### Scenario: Code block formatting mistakes
- **WHEN** the cheat sheet is used in an LLM prompt
- **THEN** it SHALL include: ` ```lang``` ` → `#+begin_src lang`

#### Scenario: Link formatting mistakes
- **WHEN** the cheat sheet is used in an LLM prompt
- **THEN** it SHALL include: `[desc](url)` → `[[url][desc]]`

### Requirement: Cheat sheet includes output wrapping rule
The cheat sheet MUST include a rule against wrapping the entire output in markdown code fences.

#### Scenario: No code fence wrapping
- **WHEN** the cheat sheet is used in an LLM prompt
- **THEN** it SHALL include the rule: never wrap the entire output in a markdown code fence

### Requirement: Cheat sheet is self-contained
The cheat sheet string MUST be self-contained with no format specifiers.

#### Scenario: No format specifiers
- **WHEN** the cheat sheet string is examined
- **THEN** it SHALL NOT contain any `%s`, `%d`, or other `format` specifiers
- **AND** it SHALL be suitable for direct concatenation into system prompts

## MODIFIED Requirements

### Requirement: Cheat sheet includes SCHEDULED time range format
The cheat sheet SHALL include the SCHEDULED time range format `SCHEDULED: <YYYY-MM-DD HH:MM-HH:MM>` in addition to the basic date-only format.

#### Scenario: Basic SCHEDULED format
- **WHEN** the cheat sheet is used in an LLM prompt
- **THEN** it SHALL include `SCHEDULED: <YYYY-MM-DD Day>` format

#### Scenario: SCHEDULED time range format
- **WHEN** the cheat sheet is used in an LLM prompt
- **THEN** it SHALL include `SCHEDULED: <YYYY-MM-DD HH:MM-HH:MM>` format for time ranges
- **AND** it SHALL note that Pass 2 may use single time format `SCHEDULED: <YYYY-MM-DD HH:MM>` or `DEADLINE: <YYYY-MM-DD HH:MM>`