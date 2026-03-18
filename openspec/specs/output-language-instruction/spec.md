# Output Language Instruction

## Purpose

(TBD)

## ADDED Requirements

### Requirement: Output language instruction is read at call time
The system SHALL read the `OUTPUT_LANGUAGE` environment variable at call time (not at load time) to allow dynamic changes without restarting the daemon.

#### Scenario: Language read at call time in task pipeline
- **WHEN** `sem-router--route-to-task-llm` is invoked
- **THEN** it SHALL read `(getenv "OUTPUT_LANGUAGE")` inside the function body, not at module load time

#### Scenario: Language read at call time in URL capture pipeline
- **WHEN** `sem-url-capture-process` is invoked
- **THEN** it SHALL read `(getenv "OUTPUT_LANGUAGE")` inside the function body, not at module load time

### Requirement: Default language is English
If the `OUTPUT_LANGUAGE` environment variable is not set, the system SHALL use "English" as the default value.

#### Scenario: Default when env var is unset
- **WHEN** `OUTPUT_LANGUAGE` environment variable is not set
- **THEN** the system SHALL use the string `"English"` as the default

#### Scenario: No error on unset env var
- **WHEN** `OUTPUT_LANGUAGE` environment variable is not set
- **THEN** the system SHALL NOT raise an error or warning

### Requirement: Language instruction is appended to system prompt
The language instruction SHALL be appended to the system prompt as the final line.

#### Scenario: Language instruction format
- **WHEN** the language instruction is generated
- **THEN** it SHALL be in the format: `\n\nOUTPUT LANGUAGE: Write your entire response in <value>. Do not use any other language.`

#### Scenario: Language instruction is final line
- **WHEN** the complete system prompt is constructed
- **THEN** the language instruction SHALL be the last content in the prompt, after the org-mode cheat sheet

### Requirement: Value is used verbatim without validation
The `OUTPUT_LANGUAGE` value SHALL be used exactly as provided without any validation or normalization.

#### Scenario: Value passed verbatim
- **WHEN** `OUTPUT_LANGUAGE` is set to a value
- **THEN** that exact value SHALL be inserted into the language instruction
- **AND** no validation or transformation SHALL be applied

#### Scenario: Invalid values produce invalid instructions
- **WHEN** `OUTPUT_LANGUAGE` is set to an invalid language name
- **THEN** the invalid value SHALL be passed to the LLM verbatim
- **AND** no error or warning SHALL be generated

### Requirement: Task pipeline includes language instruction
The task pipeline in `sem-router.el` SHALL include the output language instruction in its system prompt.

#### Scenario: Task pipeline system prompt includes language
- **WHEN** `sem-router--route-to-task-llm` builds its system prompt
- **THEN** the prompt SHALL include the concatenated: cheat sheet + task instructions + language instruction

### Requirement: URL capture pipeline includes language instruction
The URL capture pipeline in `sem-url-capture.el` SHALL include the output language instruction in its system prompt.

#### Scenario: URL capture system prompt includes language
- **WHEN** `sem-url-capture--build-system-prompt` builds its system prompt
- **THEN** the prompt SHALL include the concatenated: cheat sheet + url-capture instructions + language instruction

### Requirement: RSS pipeline is unchanged
The RSS digest pipeline in `sem-rss.el` SHALL NOT include the output language instruction.

#### Scenario: RSS not affected
- **WHEN** `sem-rss.el` is used
- **THEN** it SHALL NOT read or use the `OUTPUT_LANGUAGE` environment variable
- **AND** RSS digest language SHALL continue to be controlled via prompt files

### Requirement: Language is not cached
The system SHALL NOT cache the `OUTPUT_LANGUAGE` value in a global variable.

#### Scenario: No caching
- **WHEN** the environment variable is changed after initial load
- **THEN** subsequent calls SHALL read the new value
- **AND** no global variable SHALL store the language value