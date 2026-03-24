## 1. Seed Trusted URL-Capture Test Inputs

- [x] 1.1 Update `dev/integration/testing-resources/inbox-tasks.org` to include at least one `:link:` headline for `https://semyonsinchenko.github.io/ssinchenko/post/aider_2026_and_other_topics/` while preserving existing task fixtures.
- [x] 1.2 Ensure title/keyword choices for the new link fixture are unique enough for deterministic grep-based assertions.

## 2. Prepare Deterministic Baseline Org-Roam Fixture

- [x] 2.1 Add setup logic in `dev/integration/run-integration-tests.sh` to copy `dev/integration/testing-resources/20260313152244-llm.org` into the runtime `test-data/org-roam` directory before execution.
- [x] 2.2 Add fail-fast validation in setup that confirms seeded fixture ID `96a58b04-1f58-47c9-993f-551994939252`, title `LLM`, and canonical `:umbrella:` tagging contract.
- [x] 2.3 Record a baseline snapshot/list of org-roam files immediately after fixture seeding so pre-existing files are never counted as generated capture output.

## 3. Implement URL-Capture Assertion Block

- [x] 3.1 Add a dedicated URL-capture assertion stage in `dev/integration/run-integration-tests.sh` that always runs with the rest of assertions and participates in final pass/fail gating.
- [x] 3.2 Implement candidate discovery for newly generated org-roam files associated with the trusted URL using baseline-vs-post-run comparison.
- [x] 3.3 Assert required node structure in at least one candidate (`:PROPERTIES:`, `:ID:`, `#+title:`) and fail with actionable diagnostics if missing.
- [x] 3.4 Assert exact trusted URL preservation in both `#+ROAM_REFS` and `Source: [[URL][URL]]` within `* Summary` for at least one valid candidate.
- [x] 3.5 Assert mandatory umbrella link presence `[[id:96a58b04-1f58-47c9-993f-551994939252][...]]` in at least one valid candidate.
- [x] 3.6 Assert defanged forms (`hxxp://`, `hxxps://`) are absent from validated trusted-URL candidate nodes.

## 4. Enforce Umbrella-Link Generation Behavior

- [x] 4.1 Update URL-capture generation input/prompt construction so provided umbrella candidates require at least one explicit `[[id:<umbrella-id>][...]]` link in generated output.
- [x] 4.2 Add or update URL-capture tests to verify umbrella-link insertion is required when umbrella candidates exist, including fixture ID `96a58b04-1f58-47c9-993f-551994939252` in integration context.

## 5. Extend Run Artifact Collection

- [x] 5.1 Update artifact collection in `dev/integration/run-integration-tests.sh` to copy URL-capture org-roam output files into each `test-results/*-run/` directory.
- [x] 5.2 Add baseline-vs-new visibility in collected artifacts (manifest, naming, or directory split) so seeded fixture files are distinguishable from generated capture files.
- [x] 5.3 Ensure `validation.txt` includes URL-capture assertion output and explicit failure reasons for structure/ref/link violations.

## 6. Align Specs and Verification Surface

- [x] 6.1 Update hardcoded assertion arrays/constants in `dev/integration/run-integration-tests.sh` to match added URL-capture checks and any new keyword expectations.
- [x] 6.2 Confirm OpenSpec spec alignment by ensuring implementation behavior satisfies modified capabilities (`assertions`, `test-inbox-resource`, `run-dir-artifacts`, `test-data-isolation`, `url-capture`) and new integration capabilities.
- [x] 6.3 Run local non-paid validation steps (shell lint/static checks and targeted script dry checks where available) without executing paid integration tests.
