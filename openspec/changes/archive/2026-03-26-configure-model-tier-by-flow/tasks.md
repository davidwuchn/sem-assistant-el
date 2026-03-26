## 1. Tier Resolution in sem-llm

- [x] 1.1 Add a request-scoped tier resolver in `sem-llm` that maps `weak` and `medium` intent to concrete model identifiers.
- [x] 1.2 Keep `OPENROUTER_MODEL` as required medium/default and implement weak-tier fallback to medium when `OPENROUTER_WEAK_MODEL` is unset or empty.
- [x] 1.3 Thread tier intent through internal LLM request helpers so call sites pass explicit tier intent without mutating global model state.

## 2. Flow Mapping Updates

- [x] 2.1 Update router Pass 1 `:task:` normalization to request `weak` tier intent.
- [x] 2.2 Update router Pass 2 planning to request `medium` tier intent.
- [x] 2.3 Update URL capture and RSS digest generation call sites to request `medium` tier intent.

## 3. Model Registration and Observability

- [x] 3.1 Update runtime model registration to include resolved medium and weak model identifiers with deduplication when equal.
- [x] 3.2 Add concise startup logging that reports effective medium and weak configuration (including fallback behavior).
- [x] 3.3 Add request-boundary logging for tier-to-model selection without exposing sensitive data.

## 4. Tests and Documentation

- [x] 4.1 Add/adjust tests for flow-to-tier mapping across Pass 1, Pass 2, URL capture, and RSS flows.
- [x] 4.2 Add/adjust tests for weak-tier resolution behavior (configured weak, unset weak, empty weak).
- [x] 4.3 Add/adjust tests for deduplicated runtime model registration when weak and medium resolve to the same identifier.
- [x] 4.4 Update deployment documentation to describe optional `OPENROUTER_WEAK_MODEL` semantics and rollout/rollback behavior.
