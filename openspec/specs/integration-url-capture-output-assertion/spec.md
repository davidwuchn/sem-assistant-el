# Specification: integration-url-capture-output-assertion

## Purpose

Define integration assertions that validate URL-capture output integrity for a trusted URL.

## ADDED Requirements

### Requirement: URL-capture output satisfies trusted-URL integrity contract
The integration suite SHALL validate URL-capture output for `https://semyonsinchenko.github.io/ssinchenko/post/aider_2026_and_other_topics/` by requiring at least one newly generated org-roam node that includes required org-roam structure, exact trusted URL preservation, and mandatory umbrella-ID linking.

#### Scenario: At least one new URL-capture node exists
- **WHEN** integration artifact collection compares baseline and post-run org-roam files
- **THEN** there MUST be at least one newly generated org-roam file beyond baseline fixtures

#### Scenario: Required org-roam structure exists in candidate node
- **WHEN** validating a trusted-URL candidate captured node
- **THEN** the file MUST include `:PROPERTIES:`
- **AND** the file MUST include `:ID:` within the properties drawer
- **AND** the file MUST include `#+title:`

#### Scenario: Trusted URL preserved exactly in ROAM_REFS
- **WHEN** validating a trusted-URL candidate captured node
- **THEN** `#+ROAM_REFS:` MUST contain the exact trusted URL string

#### Scenario: Summary source link preserves exact URL
- **WHEN** validating a trusted-URL candidate captured node
- **THEN** the `* Summary` section MUST contain `Source: [[URL][URL]]` using the exact trusted URL in both link target and label

#### Scenario: Defanged URL forms are forbidden
- **WHEN** validating trusted-URL captured output
- **THEN** no validated candidate node MUST contain `hxxp://`
- **AND** no validated candidate node MUST contain `hxxps://`

#### Scenario: Umbrella link to pre-existing ID is mandatory
- **WHEN** validating trusted-URL candidate captured nodes
- **THEN** at least one candidate node MUST include a link matching `[[id:96a58b04-1f58-47c9-993f-551994939252][...]]`

#### Scenario: Multiple candidate nodes are allowed
- **WHEN** the pipeline produces multiple candidate nodes for the same trusted URL
- **THEN** assertions MUST pass only if at least one candidate node satisfies all required structure, URL, and umbrella-link constraints
