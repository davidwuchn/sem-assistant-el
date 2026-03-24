## Why

Current integration coverage validates only `tasks.org` outcomes and does not prove that the URL-capture pipeline produces a valid org-roam node, preserves real URLs, or links captured content to pre-existing umbrella knowledge. This leaves a critical production path (trusted URL ingestion via trafilatura + org-roam write + graph linking) unverified end-to-end.

## What Changes

Add integration-test planning scope for URL-capture verification using the trusted page `https://semyonsinchenko.github.io/ssinchenko/post/aider_2026_and_other_topics/`, require one pre-existing umbrella org-roam node fixture at `dev/integration/testing-resources/20260313152244-llm.org` (ID `96a58b04-1f58-47c9-993f-551994939252`, filetags containing `:umbrella:`), and require assertions/artifact collection that prove capture-file existence, mandatory org-roam structure, exact source/ref URL preservation, non-defanged URL output, and mandatory linking to the pre-existing umbrella node.

Explicit constraints and edge handling: pre-existing fixture must not be counted as newly captured output; "new file" means at least one additional org-roam file beyond baseline fixture set; URL checks apply to captured node(s) for the trusted URL only; umbrella linking is validated via explicit `[[id:96a58b04-1f58-47c9-993f-551994939252][...]]` presence; `:umbrella:` is the canonical tag (typo variants such as `:umbrealla:` are out of contract); if multiple captured nodes are produced for the same URL, assertions pass only when at least one candidate satisfies all link/ref/structure constraints.

Out of scope: semantic quality of generated summary text, exact generated title wording, exact section ordering beyond required fields, model-specific prose differences, and any changes to paid-test execution policy.

## Capabilities

### New Capabilities

- `integration-url-capture-output-assertion`: Integration validation for URL-capture output SHALL require at least one new org-roam node, required org-roam headers (`:PROPERTIES:`, `:ID:`, `#+title:`), exact trusted URL in `#+ROAM_REFS`, exact `Source: [[URL][URL]]` form in `* Summary`, absence of defanged URL forms (`hxxp://`, `hxxps://`), and presence of a link to pre-existing umbrella ID `96a58b04-1f58-47c9-993f-551994939252`; assertion scope is limited to URL-capture artifact(s), not task-generation outputs.
- `integration-preexisting-umbrella-fixture`: Integration test data SHALL source one pre-existing org-roam fixture from `dev/integration/testing-resources/20260313152244-llm.org`, then place it into the runtime org-roam test directory used by URL-capture, with fixed ID `96a58b04-1f58-47c9-993f-551994939252`, title `LLM`, and filetags including `:umbrella:llm:ai:`; fixture is immutable baseline data and must be preserved as pre-existing, not generated output.
- `integration-url-capture-artifact-collection`: Integration artifact collection SHALL capture URL-capture org-roam output files into run results so post-mortem inspection can verify graph linkage and URL integrity; collected artifacts must distinguish baseline fixture(s) from newly generated capture file(s).

### Modified Capabilities

- `test-inbox-resource`: Test inbox coverage is extended from task-only assumptions to include URL-capture exercise inputs for the trusted blog URL while preserving existing task-flow fixtures.
- `assertions`: Assertion contract is extended with a dedicated URL-capture assertion block and final-result gating that includes URL-capture pass/fail state.
- `run-dir-artifacts`: Run-directory requirements are extended to include URL-capture org-roam artifacts and baseline-vs-new capture visibility.
- `test-data-isolation`: Test-data setup requirements are extended to seed baseline org-roam state deterministically before each run by copying `dev/integration/testing-resources/20260313152244-llm.org` into the runtime org-roam test directory.
- `url-capture`: Integration verification scope is extended to require proven umbrella-node linking behavior for trusted URL capture output.

## Impact

Improves confidence in production-critical URL-capture behavior with deterministic checks for file creation, URL integrity, and graph linkage; increases integration-run strictness and artifact volume; may increase maintenance when prompt or model behavior changes around link insertion; does not change runtime daemon behavior outside integration test coverage and fixtures.
