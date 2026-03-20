## Purpose

This capability provides enhanced sensitive block detection that records semantic position metadata for each block, enabling verification that tokens appear in the correct location after LLM processing.

## ADDED Requirements

### Requirement: Position-aware sensitive block detection
The function `sem-security--detect-sensitive-blocks-with-position` SHALL detect all `#+begin_sensitive` / `#+end_sensitive` blocks and return an enhanced alist containing: the token identifier, the original block content (including markers), and surrounding context strings for semantic anchoring.

#### Scenario: Single sensitive block detected with context
- **WHEN** text contains a single sensitive block with content "Password: supersecret123"
- **THEN** the result contains token `<<SENSITIVE_1>>`
- **AND** original content `#+begin_sensitive\nPassword: supersecret123\n#+end_sensitive`
- **AND** before-context (up to 20 chars preceding the block)
- **AND** after-context (up to 20 chars following the block)

#### Scenario: Multiple sensitive blocks detected with sequential context
- **WHEN** text contains two sensitive blocks
- **THEN** the first block yields `<<SENSITIVE_1>>` with its surrounding context
- **AND** the second block yields `<<SENSITIVE_2>>` with its surrounding context

#### Scenario: Sensitive block at document start
- **WHEN** a sensitive block is at the beginning of the text
- **THEN** before-context is empty string

#### Scenario: Sensitive block at document end
- **WHEN** a sensitive block is at the end of the text
- **THEN** after-context is empty string

### Requirement: Context used for semantic position verification
The position metadata (before-context, after-context) SHALL be used to verify that tokens appear at the same semantic position in LLM output as the original sensitive content appeared in the input.

#### Scenario: Token preserved at semantic position
- **WHEN** LLM output contains `<<SENSITIVE_1>>` at a position where before-context matches
- **THEN** the token is considered semantically preserved

#### Scenario: Token missing from expected position
- **WHEN** LLM output does not contain a token that should be present based on position context
- **THEN** the missing token is flagged for investigation
