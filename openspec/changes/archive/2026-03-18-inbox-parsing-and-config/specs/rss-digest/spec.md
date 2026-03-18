## MODIFIED Requirements

### Requirement: RSS prompt builders use template variables
The functions `sem-rss--build-general-prompt` and `sem-rss--build-arxiv-prompt` SHALL replace inline `format` string literals with `format` using the loaded template variables `sem-rss-general-prompt-template` and `sem-rss-arxiv-prompt-template`. The argument order and types SHALL remain unchanged: general prompt uses (days, category-list, days, entries-text); arXiv prompt uses (category-list, days, entries-text).

#### Scenario: General prompt uses template variable
- **WHEN** `sem-rss--build-general-prompt` is called
- **THEN** it calls `(format sem-rss-general-prompt-template days category-list days entries-text)`
- **AND** it does not use a hardcoded string literal

#### Scenario: arXiv prompt uses template variable
- **WHEN** `sem-rss--build-arxiv-prompt` is called
- **THEN** it calls `(format sem-rss-arxiv-prompt-template category-list days entries-text)`
- **AND** it does not use a hardcoded string literal

#### Scenario: Template variables loaded at startup
- **WHEN** the `sem-rss` module finishes loading
- **THEN** `sem-rss-general-prompt-template` is a non-nil, non-empty string
- **AND** `sem-rss-arxiv-prompt-template` is a non-nil, non-empty string

#### Scenario: Missing template file aborts daemon
- **WHEN** the `sem-rss` module loads and a prompt file is missing or empty
- **THEN** an error is signaled and the daemon aborts startup
