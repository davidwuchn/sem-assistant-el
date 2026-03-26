## Context

The repository already has a paid, LLM-backed integration workflow for inbox processing,
but it does not provide a deterministic and no-cost way to validate git synchronization
behavior. The proposed change adds a local bare-remote test path to verify
`sem-git-sync-org-roam` behavior without OpenRouter, GitHub, or SSH key dependencies.

Current git-sync reliability checks are fragmented: unit tests validate isolated Elisp
logic, while existing integration tests focus on inbox/LLM behavior. This leaves a gap
for end-to-end verification of real git `add`/`commit`/`push` behavior and failure
classification in a hermetic local environment.

Constraints from the proposal and existing specs:
- Keep paid inbox/LLM integration flows unchanged and separate.
- Avoid production credentials and network infrastructure in routine verification.
- Preserve deterministic setup/teardown so repeated test runs are stable.

## Goals / Non-Goals

**Goals:**
- Add a deterministic integration test path that exercises real git sync behavior against
  a local bare remote over `file://` transport.
- Verify success path: local changes are committed and pushed to the local bare remote.
- Verify no-change path: when repository state is unchanged, no new commit is created and
  push remains a no-op.
- Verify failure path classification for invalid local repository and unavailable push
  target conditions.
- Keep artifacts and cleanup deterministic across repeated runs.
- Maintain strict separation from paid/internet-dependent integration assertions.

**Non-Goals:**
- Testing remote provider behavior (GitHub/GitLab uptime, auth policy, branch protection).
- Testing SSH-agent interoperability or host key handling.
- Changing cron schedule, production sync strategy, or conflict-resolution behavior.
- Replacing the existing paid integration runner and its assertion contracts.

## Decisions

### 1) Add a dedicated no-cost git-sync integration script path

**Decision:** Introduce a dedicated integration flow (script entry or clearly isolated
phase in the existing integration tooling) specifically for local bare-remote git-sync
verification.

**Rationale:** Separation keeps LLM-costing tests and git-sync tests independently
runnable. Operators can validate git-sync regressions quickly and frequently without paid
dependencies.

**Alternatives considered:**
- Extend the paid runner to also perform git-sync checks: rejected because it couples
  no-cost validation to paid credentials and longer runtime.
- Keep only unit tests: rejected because they cannot verify real git object propagation
  and transport behavior.

### 2) Use a local bare repository as canonical remote target

**Decision:** During test setup, create a local bare repository fixture and configure the
test org-roam repository remote to `file://<path-to-bare-repo>`.

**Rationale:** A bare repo provides the closest behavior to a remote endpoint while
remaining fully local, deterministic, and credential-free.

**Alternatives considered:**
- Non-bare local repo as remote: rejected because push semantics and ref updates differ
  from true remote usage.
- Networked localhost git daemon: rejected due to extra process lifecycle complexity.

### 3) Validate outcomes by inspecting remote refs and commit graph

**Decision:** Assert success/no-op behavior by checking both local status and remote
state (e.g., target branch ref existence and commit hash equality/divergence).

**Rationale:** Logs alone are insufficient for regression detection. State-based
assertions on refs/commits provide robust verification that push actually propagated.

**Alternatives considered:**
- Log-only assertions: rejected because they can pass despite partial failures.
- Filesystem timestamp checks: rejected because timestamps are nondeterministic signals.

### 4) Model explicit negative fixtures for failure classification

**Decision:** Include deterministic negative fixtures for:
- missing/invalid local git repo, and
- unavailable remote push target.

Then assert the integration flow records and reports each failure class distinctly.

**Rationale:** Failure-path regressions are high-risk in automation; explicit fixture
coverage prevents silent behavior drift.

**Alternatives considered:**
- Single generic failure test: rejected because it does not protect classification logic.

### 5) Keep paid integration contracts unchanged

**Decision:** Do not modify existing paid integration assertions unrelated to git sync;
document clear execution boundaries between paid inbox tests and no-cost git-sync tests.

**Rationale:** This preserves operational confidence in existing coverage while adding new
capability incrementally.

**Alternatives considered:**
- Merge all assertions into one unified runner contract: rejected due to increased blast
  radius and maintenance coupling.

## Risks / Trade-offs

- [Fixture complexity increases integration maintenance burden]
  -> Mitigation: centralize fixture setup/cleanup helpers and keep path conventions
  explicit and stable.
- [Local git version differences may affect edge-case behavior]
  -> Mitigation: assert on stable git primitives (refs, commit ancestry) instead of
  fragile command output formatting.
- [False confidence if failure fixtures are too narrow]
  -> Mitigation: keep two distinct negative-path fixtures aligned with proposal-defined
  failure classes.
- [Boundary drift between paid and no-cost runners over time]
  -> Mitigation: codify scope comments/docs in both runners and enforce no shared
  credential assumptions.

## Migration Plan

1. Add the dedicated local bare-remote git-sync integration flow and deterministic
   fixture directories under `dev/integration` test resources.
2. Implement success-path assertions for commit creation and remote propagation.
3. Implement no-change assertions ensuring no additional commit is produced on
   repeated sync with unchanged content.
4. Implement failure fixtures and assertions for invalid local repo and unavailable
   remote target.
5. Update documentation to clarify separation between paid inbox/LLM integration
   coverage and no-cost git-sync coverage.
6. Validate repeatability by running the no-cost flow multiple times and confirming
   deterministic setup/cleanup outcomes.

## Open Questions

- Should the no-cost git-sync flow be a standalone script or a subcommand/mode of the
  existing integration runner? (Either is acceptable if execution boundaries remain
  explicit and deterministic.)
