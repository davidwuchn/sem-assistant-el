## Why

The current end-to-end integration flow validates inbox and LLM behavior but does not provide a deterministic, zero-cost verification path for git synchronization behavior. Git sync regressions can therefore go undetected unless operators run paid tests or manually inspect repository state.

## What Changes

Add a dedicated non-LLM integration capability that validates `sem-git-sync-org-roam` against a local bare Git remote (`file://`), with no external network dependencies and no SSH dependency. The change defines explicit pass/fail expectations for success, no-change, and failure paths while preserving existing paid integration workflow boundaries.

## Capabilities

### New Capabilities

- `git-sync-local-bare-remote-test`: Provide a deterministic integration test path that exercises real `git add/commit/push` behavior against a local bare remote under isolated test data; MUST require no OpenRouter calls, no GitHub access, and no host SSH keys; MUST verify commit propagation to remote; MUST verify no-op behavior when there are no local changes; MUST verify failure classification when local repo is missing/invalid or remote push target is unavailable; MUST keep all artifacts and cleanup deterministic across repeated runs.

### Modified Capabilities

- `github-sync-readiness`: Extend readiness verification to include an explicit non-network validation path for scheduled git-sync behavior, including boundaries that keep production credentials and remote infrastructure out of scope for routine integration verification.
- `integration-test-runner`: Clarify that paid inbox/LLM integration coverage remains separate and unchanged, and that git-sync reliability can be validated via an independent no-cost flow without altering existing assertion contracts for the inbox pipeline.

## Impact

- Reduces regression risk for git-sync core behavior without incurring LLM API cost.
- Improves operator confidence through repeatable local verification of commit/push outcomes.
- Preserves current production and paid integration boundaries by keeping credentialed network paths out of this change.
- Out of scope: conflict-resolution automation, remote hosting provider behavior (GitHub/GitLab availability), SSH agent interoperability, branch strategy changes, cron schedule changes, and any modification to existing paid integration assertions unrelated to git sync.
