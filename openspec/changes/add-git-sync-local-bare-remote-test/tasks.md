## 1. Add local git-sync integration execution path

- [ ] 1.1 Inspect `dev/integration/run-integration-tests.sh` and isolate paid inbox/LLM assertions from a new local git-sync-only execution path.
- [ ] 1.2 Implement a deterministic local git-sync path that runs without `OPENROUTER_KEY` and does not invoke LLM/network-dependent steps.
- [ ] 1.3 Keep existing paid inbox flow behavior unchanged and document the execution boundary in runner comments.

## 2. Build deterministic local bare-remote fixtures

- [ ] 2.1 Add fixture setup helpers that create an isolated local org-roam git repository and a local bare remote configured via `file://` origin.
- [ ] 2.2 Add deterministic artifact directory naming and teardown so repeated runs start from clean state.
- [ ] 2.3 Add fixture validation checks that fail fast when local repo or remote setup is incomplete.

## 3. Add success and no-op git-sync assertions

- [ ] 3.1 Implement a changed-content scenario that runs `sem-git-sync-org-roam` and verifies local `HEAD` advances by one commit.
- [ ] 3.2 Verify push propagation by asserting the local branch tip equals the bare remote branch tip after a successful sync.
- [ ] 3.3 Implement a clean-repository no-op scenario that verifies success result with unchanged local commit count and unchanged remote tip.

## 4. Add deterministic failure classification coverage

- [ ] 4.1 Implement an invalid local repository fixture and assert `sem-git-sync-org-roam` reports a failure outcome.
- [ ] 4.2 Implement an unavailable local push target fixture and assert sync fails without reporting success.
- [ ] 4.3 Ensure failure-path assertions distinguish repository-state failure from push-target failure in runner output.

## 5. Update docs and validate repeatability

- [ ] 5.1 Update integration testing documentation to describe when to run paid inbox tests versus no-cost local git-sync validation.
- [ ] 5.2 Add operator-facing instructions for the local git-sync path, including expected artifacts and failure signals.
- [ ] 5.3 Run the local git-sync validation path multiple times and confirm deterministic setup/cleanup and stable assertion results.
