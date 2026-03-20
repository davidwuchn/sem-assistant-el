## Purpose

This capability defines the RSS digest generation module that processes feeds via LLM.

## MODIFIED Requirements

### Requirement: when-let* replacement for Emacs 31.1 compatibility
The `sem-rss` module SHALL use `when-let*` instead of the obsolete `when-let` macro for Emacs 31.1 compatibility. The `when-let*` macro performs sequential binding (like `let*`), whereas the deprecated `when-let` performed parallel binding.

#### Scenario: sem-rss uses when-let*
- **WHEN** `sem-rss-max-entries-per-feed` or `sem-rss-max-input-chars` are evaluated
- **THEN** `when-let*` is used for binding (not obsolete `when-let`)

#### Scenario: when-let* bindings are independent
- **WHEN** `when-let*` is used in defconst initializers
- **THEN** the bindings are independent and sequential binding produces correct results
