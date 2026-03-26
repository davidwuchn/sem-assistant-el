## Why

The current system uses one model for all LLM flows, which prevents cost and latency optimization for lightweight normalization work. Pass 1 task normalization can use a weaker model, while Pass 2 planning, link capture, and RSS digest generation should continue using the default medium model.

## What Changes

- Introduce flow-based model tier selection through configuration.
- Keep one required model variable for default/medium behavior.
- Add one optional weak-model variable for Pass 1 task normalization.
- Define explicit fallback behavior when the weak model is not configured.
- Ensure model registration includes all configured models used by runtime selection.
- Add startup/runtime observability for selected tier/model decisions.
- Update operator-facing configuration documentation.

## Capabilities

### New Capabilities

- `flow-model-tier-selection`: The system selects model tier by flow with strict mapping and constraints:
  - Pass 1 `:task:` normalization uses weak tier.
  - Pass 2 planning uses medium tier.
  - `:link:` capture uses medium tier.
  - RSS digest generation uses medium tier.
  - `OPENROUTER_MODEL` is required and is the medium/default model.
  - `OPENROUTER_WEAK_MODEL` is optional.
  - If `OPENROUTER_WEAK_MODEL` is unset or empty, weak tier MUST fall back to `OPENROUTER_MODEL`.
  - Per-request model selection MUST avoid global mutable model switching semantics.
  - Runtime model registration MUST include both configured model identifiers, with deduplication when values match.

### Modified Capabilities

- `llm-request-routing`: Existing LLM request handling is extended to accept and honor model-tier intent from callers while preserving current retry/error semantics.
- `runtime-configuration`: Environment-driven model config is expanded from single-model to default-plus-optional-weak model without changing required baseline startup behavior.
- `operator-config-docs`: Environment and deployment docs are updated to describe weak-tier optionality and fallback semantics.

## Impact

- Improves cost/latency control for Pass 1 without reducing capability of planning/link/RSS flows.
- Preserves backward compatibility for deployments that only set `OPENROUTER_MODEL`.
- Reduces configuration complexity relative to multi-required-model approaches (one required, one optional).
- Explicitly out of scope:
  - Quality tuning or evaluation of model output behavior by flow.
  - Any change to retry budgets, DLQ policy, prompt templates, or planning logic semantics.
  - Additional tiers beyond weak and medium.
  - Provider-level routing changes beyond model selection within existing OpenRouter integration.
