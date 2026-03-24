# Specification: integration-preexisting-umbrella-fixture

## Purpose

Define deterministic baseline umbrella-fixture requirements for URL-capture integration runs.

## ADDED Requirements

### Requirement: Integration run seeds a fixed pre-existing umbrella fixture
The integration suite SHALL copy `dev/integration/testing-resources/20260313152244-llm.org` into the runtime org-roam test directory before URL-capture execution as immutable baseline data.

#### Scenario: Fixture source path is fixed
- **WHEN** test-data setup prepares runtime state
- **THEN** it MUST source the fixture from `dev/integration/testing-resources/20260313152244-llm.org`

#### Scenario: Fixture identity is stable
- **WHEN** the fixture is present in runtime org-roam data
- **THEN** the fixture MUST contain ID `96a58b04-1f58-47c9-993f-551994939252`
- **AND** the fixture title MUST be `LLM`
- **AND** filetags MUST include `:umbrella:llm:ai:`

#### Scenario: Fixture remains baseline, not generated output
- **WHEN** URL-capture output assertions determine newly created files
- **THEN** the seeded fixture MUST be treated as pre-existing baseline
- **AND** it MUST NOT be counted as newly captured output

#### Scenario: Canonical umbrella tag required
- **WHEN** validating fixture contract
- **THEN** the canonical tag MUST be `:umbrella:`
- **AND** typo variants (including `:umbrealla:`) MUST be rejected for this capability
