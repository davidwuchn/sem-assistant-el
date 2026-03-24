## Context

The integration suite currently proves task-generation outcomes but does not fully verify the URL-capture path that writes org-roam nodes from trusted URLs. This change adds deterministic coverage for:
- trusted URL ingestion for `https://semyonsinchenko.github.io/ssinchenko/post/aider_2026_and_other_topics/`
- org-roam node structure and reference integrity
- mandatory link creation to a pre-seeded umbrella node (`96a58b04-1f58-47c9-993f-551994939252`)
- run artifact capture that separates baseline fixtures from newly generated files

The existing integration runner already manages isolated run directories and assertion gating. The design extends those flows without changing daemon runtime behavior.

## Goals / Non-Goals

**Goals:**
- Ensure integration runs fail when URL-capture output misses required org-roam fields (`:PROPERTIES:`, `:ID:`, `#+title:`), exact `#+ROAM_REFS`, or exact `Source: [[URL][URL]]` format in `* Summary`.
- Ensure integration runs fail when captured output contains defanged URL forms (`hxxp://`, `hxxps://`) for the trusted URL case.
- Seed and preserve a deterministic pre-existing umbrella fixture from `dev/integration/testing-resources/20260313152244-llm.org` and require an explicit `[[id:96a58b04-1f58-47c9-993f-551994939252][...]]` link in at least one new captured node.
- Capture URL-capture org-roam outputs as run artifacts with clear baseline-vs-new visibility.

**Non-Goals:**
- Evaluating semantic quality of generated summaries.
- Enforcing exact title wording or full section ordering beyond required fields.
- Changing integration execution policy (including paid-call constraints) or daemon production code paths.

## Decisions

1. Add a dedicated URL-capture assertion block in the integration runner.
   - Rationale: URL-capture constraints are distinct from task assertions and need independent pass/fail signals for diagnosis.
   - Alternative considered: Fold checks into existing generic assertions. Rejected because failures become ambiguous and harder to maintain.

2. Use baseline snapshot comparison in the org-roam runtime directory to identify newly generated capture files.
   - Rationale: The fixture is intentionally pre-existing and must never be counted as output; baseline diffing gives deterministic separation.
   - Alternative considered: Infer "new" by filename pattern/timestamp only. Rejected because naming and timing can vary and are less reliable.

3. Validate trusted-URL requirements against candidate captured nodes and pass only if at least one candidate satisfies all required structure/ref/link checks.
   - Rationale: The pipeline may emit multiple nodes for a single URL in edge cases; contract requires at least one fully valid node.
   - Alternative considered: Require exactly one matching node. Rejected as brittle against non-contractual multiplicity.

4. Preserve exact URL forms in assertions (`https://...`) and explicitly reject defanged forms.
   - Rationale: The production contract requires real URLs for traceability and downstream automation.
   - Alternative considered: Normalize both forms before compare. Rejected because it would hide a class of output corruption.

5. Collect URL-capture outputs into run results with explicit baseline/new categorization metadata.
   - Rationale: Post-mortem debugging needs direct evidence of what was generated vs seeded.
   - Alternative considered: Store only assertion logs. Rejected due to insufficient forensic detail for link and header issues.

## Risks / Trade-offs

- [Model output variability around source/link formatting] -> Mitigation: scope assertions to strict contract fields only and allow success if any candidate node satisfies all mandatory checks.
- [False negatives from fixture copy/setup drift] -> Mitigation: deterministic fixture path and ID checks during setup; fail fast when fixture not present or malformed.
- [Higher maintenance burden for integration assertions] -> Mitigation: centralize URL-capture checks in one assertion block and document trusted-URL contract in spec artifacts.
- [Increased artifact volume per run] -> Mitigation: retain focused artifact set (captured files plus baseline/new manifest) and avoid duplicating unchanged fixtures.

## Migration Plan

1. Extend integration test resources to include URL-capture exercise input in inbox fixtures.
2. Update test-data setup to copy `dev/integration/testing-resources/20260313152244-llm.org` into runtime org-roam dir before execution.
3. Add URL-capture assertion stage to the integration runner and include its result in final pass/fail gating.
4. Add artifact collection logic for URL-capture org-roam files with baseline/new differentiation.
5. Validate locally with non-integration unit/lint checks as applicable; human operators run paid integration suite manually.
6. Rollback strategy: revert runner assertion/artifact changes and fixture-seeding additions if failures become unstable.

## Open Questions

- Should baseline/new differentiation be persisted as a separate manifest file in run artifacts, or only represented by directory structure and naming?
- Should trusted URL checks remain single-URL scoped, or be made extensible to a small allowlist for future scenarios?
- If multiple candidate nodes satisfy all constraints, do we need deterministic preference for reporting (for stable debugging output)?
