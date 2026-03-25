## 1. Router Task Title Normalization

- [x] 1.1 Add a helper in `app/elisp/sem-router.el` that lowercases only the TODO headline title text while preserving optional priority markers.
- [x] 1.2 Integrate the helper into the `:task:` pipeline after `sem-router--validate-task-response` and before file write.
- [x] 1.3 Ensure normalization affects only the first TODO headline line and leaves body, drawers, IDs, and scheduling/deadline lines unchanged.

## 2. URL-Capture Prompt Guidance

- [x] 2.1 Update `sem-url-capture--build-user-prompt` in `app/elisp/sem-url-capture.el` to include concise, semantically compressed `#+title:` guidance.
- [x] 2.2 Add concrete examples in prompt text that show shorter high-signal title rewrites without hard truncation rules.
- [x] 2.3 Keep all existing structural requirements (ID, properties, refs, org format, umbrella linking) intact.

## 3. Automated Test Coverage

- [x] 3.1 Add router tests in `app/elisp/tests/sem-router-test.el` for mixed-case-to-lowercase normalization and idempotency.
- [x] 3.2 Add router tests verifying priority markers are preserved and non-title content is unchanged.
- [x] 3.3 Add URL-capture prompt-builder tests in `app/elisp/tests/sem-url-capture-test.el` asserting concise-title guidance and examples are present.

## 4. Verification

- [x] 4.1 Run targeted ERT files for router and URL-capture modules and fix any failures.
- [x] 4.2 Run full suite with `eask test ert app/elisp/tests/sem-test-runner.el`.
- [x] 4.3 Confirm no integration test scripts were run and document verification results in the change notes if needed.
