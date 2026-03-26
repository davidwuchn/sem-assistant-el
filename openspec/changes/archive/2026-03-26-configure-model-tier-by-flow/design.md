## Context

Today all LLM flows share a single model identifier configured through `OPENROUTER_MODEL`.
This creates unnecessary cost and latency for lightweight Pass 1 `:task:` normalization,
while higher-value flows (Pass 2 planning, `:link:` capture, RSS digest generation)
benefit from keeping current medium-tier behavior.

The change must preserve existing deployments that only configure one model, avoid
global mutable model switching, and keep current retry/error behavior unchanged.

## Goals / Non-Goals

**Goals:**
- Introduce deterministic flow-to-tier mapping (weak vs medium).
- Keep `OPENROUTER_MODEL` as required default/medium model.
- Add optional `OPENROUTER_WEAK_MODEL` with explicit fallback to medium when unset.
- Ensure runtime model registration includes all configured models with deduplication.
- Add observability so operators can verify selected tier/model at startup and runtime.

**Non-Goals:**
- Add new tiers beyond weak and medium.
- Change prompt content, planner logic, retry budgets, or DLQ behavior.
- Perform provider-routing redesign beyond model selection.
- Introduce quality scoring or model-evaluation workflows.

## Decisions

### 1) Centralize tier resolution in `sem-llm`

Decision:
- Add a single tier-resolution path in the LLM wrapper (for example, a resolver that
  maps `weak`/`medium` tier intent to a concrete model string).
- Callers pass tier intent per request; they do not mutate global model state.

Rationale:
- Keeps all model-selection rules in one module.
- Prevents cross-flow races and hidden side effects from mutable globals.

Alternatives considered:
- Per-module model selection logic in router/rss/url modules: rejected due to rule drift
  and duplicated fallback behavior.
- Temporarily rebinding a global model variable per flow: rejected due to concurrency and
  readability risks.

### 2) Use explicit flow-to-tier mapping at call sites

Decision:
- Pass 1 `:task:` normalization requests `weak` tier.
- Pass 2 planning, `:link:` capture, and RSS digest requests `medium` tier.

Rationale:
- Keeps intent clear where requests are initiated.
- Supports future extension without changing semantic meaning of existing calls.

Alternatives considered:
- Infer tier from prompt text or token size: rejected as brittle and hard to reason about.
- Global default tier with local overrides: rejected because explicit mapping is clearer.

### 3) Environment contract remains backward compatible

Decision:
- `OPENROUTER_MODEL` remains required and represents medium/default.
- `OPENROUTER_WEAK_MODEL` is optional; nil/empty resolves to `OPENROUTER_MODEL`.

Rationale:
- Existing operators need zero required config changes.
- Weak-tier adoption is opt-in with safe fallback.

Alternatives considered:
- Require both environment variables: rejected due to unnecessary migration burden.

### 4) Register both configured models with deduplication

Decision:
- Startup/runtime registration collects model identifiers for medium and weak,
  deduplicates when equal, and registers the resulting set.

Rationale:
- Ensures all runtime-selected models are known/registered.
- Avoids redundant registration when weak falls back to medium.

Alternatives considered:
- Register only medium always: rejected because explicitly configured weak model might
  be unavailable if not registered.

### 5) Add low-noise observability

Decision:
- Log effective model configuration at startup (medium set, weak configured/fallback).
- Log tier-to-model selection at request boundary without exposing secrets.

Rationale:
- Operators can verify behavior quickly during rollout and incident response.

Alternatives considered:
- No new logs: rejected because flow-based selection is otherwise opaque in production.

## Risks / Trade-offs

- [Risk] Tier intent is omitted at a call site, causing unintended default behavior
  -> Mitigation: make tier an explicit parameter for internal request helpers and add
  tests for each flow mapping.
- [Risk] Weak model quality is insufficient for some task normalization edge cases
  -> Mitigation: fallback remains medium by configuration; operators can disable weak
  by unsetting `OPENROUTER_WEAK_MODEL`.
- [Risk] Logging increases noise
  -> Mitigation: keep messages concise and event-scoped; avoid per-token verbosity.

## Migration Plan

1. Implement tier-aware request path in `sem-llm` with backward-compatible defaults.
2. Update flow call sites (`:task:` pass 1, planning pass 2, link capture, RSS) to pass
   explicit tier intent.
3. Update model registration logic to include deduplicated medium+weak set.
4. Add/adjust tests for fallback, mapping correctness, and registration behavior.
5. Update deployment docs for new optional `OPENROUTER_WEAK_MODEL` semantics.
6. Roll out with existing `OPENROUTER_MODEL` only, then optionally enable weak model.

Rollback strategy:
- Remove/unset `OPENROUTER_WEAK_MODEL` to force all flows back to medium immediately.
- If needed, revert code while preserving existing single-model environment behavior.

## Open Questions

- Should request-level logs include the calling flow identifier in addition to tier,
  or only tier+model to minimize coupling?
- Do we need a startup warning when weak equals medium explicitly, or is silent
  deduplication sufficient?
