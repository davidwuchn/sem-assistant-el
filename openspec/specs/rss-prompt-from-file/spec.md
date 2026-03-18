## Purpose

This capability defines the RSS prompt template loading system that reads prompt templates from external files at module startup.

## Requirements

### Requirement: RSS prompt templates loaded from external files
The system SHALL read RSS prompt templates from `/data/prompts/general-prompt.txt` and `/data/prompts/arxiv-prompt.txt` at module load time. The content SHALL be stored in two `defvar` globals: `sem-rss-general-prompt-template` and `sem-rss-arxiv-prompt-template`.

#### Scenario: Prompt files exist and are loaded
- **WHEN** the `sem-rss` module loads and both prompt files exist with content
- **THEN** `sem-rss-general-prompt-template` contains the content of `/data/prompts/general-prompt.txt`
- **AND** `sem-rss-arxiv-prompt-template` contains the content of `/data/prompts/arxiv-prompt.txt`

#### Scenario: Missing prompt file causes hard error
- **WHEN** the `sem-rss` module loads and `/data/prompts/general-prompt.txt` does not exist
- **THEN** an error is signaled and the daemon aborts startup

#### Scenario: Empty prompt file causes hard error
- **WHEN** the `sem-rss` module loads and `/data/prompts/arxiv-prompt.txt` exists but is empty
- **THEN** an error is signaled and the daemon aborts startup

### Requirement: Prompt builders use loaded templates
The functions `sem-rss--build-general-prompt` and `sem-rss--build-arxiv-prompt` SHALL use `format` with the loaded template variables instead of inline string literals. The argument order and types SHALL remain unchanged.

#### Scenario: General prompt built from template
- **WHEN** `sem-rss--build-general-prompt` is called with arguments (days, category-list, days, entries-text)
- **THEN** it returns `(format sem-rss-general-prompt-template days category-list days entries-text)`

#### Scenario: arXiv prompt built from template
- **WHEN** `sem-rss--build-arxiv-prompt` is called with arguments (category-list, days, entries-text)
- **THEN** it returns `(format sem-rss-arxiv-prompt-template category-list days entries-text)`

#### Scenario: Template variables populated at load time
- **WHEN** checking `sem-rss-general-prompt-template` and `sem-rss-arxiv-prompt-template` after module load
- **THEN** both variables are non-nil and non-empty strings
