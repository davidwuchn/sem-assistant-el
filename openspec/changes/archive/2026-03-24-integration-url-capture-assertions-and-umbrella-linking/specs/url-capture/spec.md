# Specification: url-capture

## MODIFIED Requirements

### Requirement: LLM generates structured org-roam node
The system SHALL send the sanitized content and umbrella node context to the LLM. The LLM SHALL return a structured org-roam node with `:PROPERTIES:`, `:ID:`, `#+title:`, `#+ROAM_REFS:`, and content sections. When umbrella node context is provided, generated output SHALL include at least one explicit org link to a relevant umbrella node ID.

#### Scenario: Valid org-roam node generated
- **WHEN** the LLM receives valid input
- **THEN** it returns a properly formatted org-roam node with all required fields

#### Scenario: Umbrella node linked when umbrella context exists
- **WHEN** umbrella node candidates are provided to URL-capture generation
- **THEN** the generated output MUST include at least one `[[id:<umbrella-id>][...]]` link to a provided umbrella node

#### Scenario: Trusted integration fixture link is supported
- **WHEN** trusted URL-capture integration runs provide umbrella fixture ID `96a58b04-1f58-47c9-993f-551994939252`
- **THEN** at least one generated candidate node MUST be able to include `[[id:96a58b04-1f58-47c9-993f-551994939252][...]]` so integration assertions can verify graph linkage
