## Purpose

This capability defines deterministic model-tier selection per flow so requests use the intended model quality level while preserving backward compatibility.

## Requirements

### Requirement: Flow-to-tier mapping is deterministic
The system SHALL select model tier by flow using a fixed mapping: Pass 1 `:task:` normalization SHALL use `weak`, Pass 2 planning SHALL use `medium`, `:link:` capture SHALL use `medium`, and RSS digest generation SHALL use `medium`.

#### Scenario: Pass 1 uses weak tier
- **WHEN** the router submits the Pass 1 `:task:` normalization request
- **THEN** the request is executed with `weak` tier intent

#### Scenario: Pass 2 uses medium tier
- **WHEN** the router submits the Pass 2 planning request
- **THEN** the request is executed with `medium` tier intent

#### Scenario: Link capture uses medium tier
- **WHEN** URL capture submits a summarization request
- **THEN** the request is executed with `medium` tier intent

#### Scenario: RSS digest uses medium tier
- **WHEN** RSS processing submits a digest-generation request
- **THEN** the request is executed with `medium` tier intent

### Requirement: Weak tier fallback preserves backward compatibility
`OPENROUTER_MODEL` SHALL remain required as the medium/default model, `OPENROUTER_WEAK_MODEL` SHALL be optional, and weak-tier resolution SHALL fall back to `OPENROUTER_MODEL` when `OPENROUTER_WEAK_MODEL` is unset or empty.

#### Scenario: Weak model configured
- **WHEN** `OPENROUTER_WEAK_MODEL` is set to a non-empty value
- **THEN** weak-tier requests resolve to `OPENROUTER_WEAK_MODEL`

#### Scenario: Weak model unset
- **WHEN** `OPENROUTER_WEAK_MODEL` is missing
- **THEN** weak-tier requests resolve to `OPENROUTER_MODEL`

#### Scenario: Weak model empty
- **WHEN** `OPENROUTER_WEAK_MODEL` is an empty string
- **THEN** weak-tier requests resolve to `OPENROUTER_MODEL`

### Requirement: Runtime model registration includes all selectable models
Runtime model registration SHALL include both medium and weak configured identifiers, and SHALL deduplicate entries when the two resolved model identifiers are equal.

#### Scenario: Distinct weak and medium models
- **WHEN** `OPENROUTER_MODEL` and `OPENROUTER_WEAK_MODEL` are different non-empty identifiers
- **THEN** both identifiers are present in the registered model set

#### Scenario: Weak equals medium after resolution
- **WHEN** weak-tier resolves to the same identifier as medium
- **THEN** the registered model set contains that identifier once

### Requirement: Tier selection is request-scoped
Model-tier selection SHALL be applied per request and MUST NOT rely on global mutable model switching semantics.

#### Scenario: Concurrent requests with different tiers
- **WHEN** one flow submits a weak-tier request while another submits a medium-tier request
- **THEN** each request is executed against its own resolved model without mutating global selection state
