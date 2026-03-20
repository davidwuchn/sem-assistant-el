## Purpose

This capability defines the integration test verification that restored sensitive content appears in the same order as the original blocks in the input.

## ADDED Requirements

### Requirement: Order verification in integration tests
The integration test SHALL verify that sensitive keywords appear in the output file in the same order as they appeared in the original inbox input. This ensures the detokenization process maintains block ordering.

#### Scenario: Order preserved for single-line sensitive blocks
- **WHEN** inbox contains multiple single-line sensitive blocks
- **THEN** the restored sensitive content appears in the same order in the output

#### Scenario: Order preserved for multi-line sensitive blocks
- **WHEN** inbox contains multiple multi-line sensitive blocks
- **THEN** the restored sensitive content appears in the same order in the output

#### Scenario: Order verified by keyword sequence
- **WHEN** integration test runs
- **THEN** it extracts sensitive keywords from inbox in order
- **AND** it verifies the same keywords appear in the same order in the output file