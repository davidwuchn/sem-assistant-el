## Context

The change adjusts title behavior in two independent LLM pipelines:

- `:task:` flow in `app/elisp/sem-router.el` currently sends the raw inbox headline title to Pass 1 prompt construction and writes whatever validated title is returned.
- `:link:` flow in `app/elisp/sem-url-capture.el` builds prompts that request `#+title: <Article Title>` but does not guide the model toward concise node names.

The proposal requires deterministic lowercase normalization for generated task titles and shorter, semantically compressed URL-capture titles without hard truncation rules. Existing guardrails (UUID injection/validation, security token preservation, output-language behavior, and org formatting constraints) must remain unchanged.

## Goals / Non-Goals

**Goals:**
- Make task titles produced by the `:task:` pipeline deterministic by lowercasing title text before persistence.
- Keep normalization scoped to title text only, preserving body, metadata drawers, IDs, tags, and scheduling/deadline lines.
- Keep normalization idempotent so retries/reprocessing do not further alter already-normalized titles.
- Improve `:link:` title quality by updating prompt instructions toward concise, high-signal names with semantic compression examples.

**Non-Goals:**
- No retroactive rewrite of existing task entries or org-roam files.
- No hard max-length enforcement, regex-based truncation, or post-generation title clipping for URL-capture.
- No changes to language translation policy, punctuation policy beyond lowercase conversion, or non-title metadata fields.

## Decisions

### 1) Normalize task titles in Elisp after LLM response validation

Decision: add a router-side transformation step that lowercases only the task headline title segment after `sem-router--validate-task-response` succeeds and before `sem-router--write-task-to-file` persists content.

Rationale:
- Deterministic behavior belongs in code, not probabilistic LLM compliance.
- Preserves existing prompt/validation contracts and reduces risk of broad prompt regressions.
- Guarantees idempotency because lowercasing an already-lowercase title is a no-op.

Alternatives considered:
- Prompt-only instruction to emit lowercase titles: rejected as non-deterministic and model-dependent.
- Normalize raw inbox headline before prompt: rejected because model output may still produce mixed case.
- Global downcase on whole output: rejected because it would corrupt body text, links, identifiers, and metadata.

### 2) Limit normalization scope to the first TODO headline line

Decision: parse/replace only the first line matching the Org TODO headline pattern and lowercase only the title tail (after TODO and optional priority token).

Rationale:
- Meets the requirement to touch title only.
- Keeps `[ #A/#B/#C ]` style priority token semantics intact.
- Avoids modifying multiline body content and property drawers.

Alternatives considered:
- Reconstruct entry with full Org parser rewrite: rejected as unnecessary complexity for a single-field transform.
- Normalize all heading lines in response: rejected because the expected response is a single TODO entry and broad matching increases accidental edits.

### 3) Update URL-capture prompt text in user prompt template path

Decision: adjust `sem-url-capture--build-user-prompt` guidance by adding concise-title preference language and concrete semantic-compression examples near expected output format.

Rationale:
- User prompt is where task-specific style guidance already lives.
- Keeps system prompt rules focused on structural correctness while user prompt steers content quality.
- Avoids deterministic clipping that would violate proposal scope.

Alternatives considered:
- Add strict character cap to validator/save stage: rejected (out of scope and potentially destructive to meaning).
- Move all style guidance to system prompt: rejected to reduce risk of over-constraining format-focused system instructions.

### 4) Cover behavior with targeted unit tests

Decision: extend router tests to verify lowercase-title normalization is applied, title-only scope is respected, and transformation is idempotent; extend URL-capture prompt-builder tests to assert concise-title instruction/examples are present.

Rationale:
- Prevents regressions in both paths touched by this change.
- Aligns with existing module-level test organization in `app/elisp/tests/`.

Alternatives considered:
- Rely on integration tests only: rejected due to cost and slower feedback.

## Risks / Trade-offs

- [Risk] Headline regex/transform could miss unusual but valid TODO headline variants. -> Mitigation: implement conservative pattern matching around existing normalized output contract and add tests for priority/no-priority forms.
- [Risk] Lowercasing may reduce readability for acronyms or case-sensitive tokens in task titles. -> Mitigation: accepted trade-off per proposal; keep scope title-only so body retains original case where needed.
- [Risk] Stronger concise-title guidance may occasionally over-compress nuance in URL node titles. -> Mitigation: provide examples that preserve key topic signal and avoid hard rules; keep downstream manual editing available.

## Migration Plan

1. Implement router title-normalization helper and wire it into the validated write path.
2. Update URL-capture prompt builder text for concise title generation guidance.
3. Add/adjust ERT unit tests for router normalization and URL prompt content.
4. Run relevant test files and full ERT suite (`eask test ert app/elisp/tests/sem-test-runner.el`).
5. Deploy normally; no data migration required because behavior only affects newly processed items.

Rollback strategy:
- Revert the router normalization helper integration and prompt-text edits; existing stored tasks/nodes remain unchanged.

## Open Questions

- Should lowercase normalization be ASCII-only (`downcase`) or locale-aware (`downcase` already follows Emacs case tables)? Current design keeps default Emacs behavior unless requirements specify otherwise.
- For URL-capture, should concise-title examples be language-sensitive when `OUTPUT_LANGUAGE` is non-English, or remain structurally language-agnostic examples? Current design uses language-agnostic guidance.
