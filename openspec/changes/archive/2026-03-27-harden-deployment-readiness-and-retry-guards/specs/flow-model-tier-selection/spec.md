## MODIFIED Requirements

### Requirement: Weak tier fallback preserves backward compatibility
`OPENROUTER_MODEL` SHALL remain required as the medium/default model, `OPENROUTER_WEAK_MODEL` SHALL be optional, runtime container wiring SHALL pass `OPENROUTER_WEAK_MODEL` through to the daemon process when set, and weak-tier resolution SHALL fall back to `OPENROUTER_MODEL` when `OPENROUTER_WEAK_MODEL` is unset or empty.

#### Scenario: Weak model configured
- **WHEN** `OPENROUTER_WEAK_MODEL` is set to a non-empty value and provided in container runtime environment
- **THEN** weak-tier requests resolve to `OPENROUTER_WEAK_MODEL`

#### Scenario: Weak model unset
- **WHEN** `OPENROUTER_WEAK_MODEL` is missing
- **THEN** weak-tier requests resolve to `OPENROUTER_MODEL`

#### Scenario: Weak model empty
- **WHEN** `OPENROUTER_WEAK_MODEL` is an empty string
- **THEN** weak-tier requests resolve to `OPENROUTER_MODEL`
