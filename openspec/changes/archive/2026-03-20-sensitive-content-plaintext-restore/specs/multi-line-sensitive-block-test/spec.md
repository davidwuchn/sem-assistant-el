## Purpose

This capability defines the integration test inbox entry that includes a multi-line sensitive block for comprehensive coverage of the restoration process.

## ADDED Requirements

### Requirement: Multi-line sensitive block in test inbox
The integration test inbox SHALL include at least one multi-line sensitive block to verify that the restoration process correctly handles content spanning multiple lines, including proper indentation and newline handling.

#### Scenario: Multi-line block with IBAN and account number
- **WHEN** inbox-tasks.org is processed
- **THEN** it contains a multi-line sensitive block with IBAN and account number
- **AND** the block spans at least 3 lines

#### Scenario: Multi-line content formatted correctly in output
- **WHEN** multi-line sensitive block is restored
- **THEN** each line is indented by 2 spaces
- **AND** a leading newline precedes the content
- **AND** a trailing newline follows the content