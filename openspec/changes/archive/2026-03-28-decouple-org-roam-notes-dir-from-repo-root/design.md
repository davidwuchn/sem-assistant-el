## Context

The current implementation mixes two filesystem responsibilities under one implicit root (`/data/org-roam`):
1) org-roam note storage and DB scanning, and
2) git repository initialization and synchronization.

The second-brain repository treats `org-files/` as the canonical notes subtree. When SEM writes nodes directly under `/data/org-roam`, those nodes can fall outside the expected subtree and downstream tooling can miss them.

This change introduces an explicit path contract:
- Notes root: `/data/org-roam/org-files/` for all org-roam note creation and DB lifecycle.
- Repo root: `/data/org-roam` for git readiness checks, staging, commit, and push.

The design must preserve existing daemon behavior (task routing, git sync cadence, logging semantics) while removing path ambiguity.

## Goals / Non-Goals

**Goals:**
- Establish separate, explicit configuration values for notes root and repository root.
- Ensure org-roam write/read/index operations use notes root only.
- Ensure git-sync setup and operations use repository root only.
- Keep integration assertions and documentation aligned with the decoupled contract.

**Non-Goals:**
- Migrating historical notes between directories.
- Restructuring repository layout beyond using existing `org-files/` subtree.
- Changing task routing paths (for example `tasks.org`) unless required by path contract fixes.
- Changing feature behavior unrelated to path resolution.

## Decisions

### 1) Introduce two first-class path concepts
- Decision: represent notes root and git repo root as distinct configuration/runtime values.
- Rationale: removes implicit coupling and prevents accidental reuse of one path for unrelated responsibilities.
- Alternatives considered:
  - Keep one root and derive behavior contextually: rejected because call sites cannot reliably infer intent and regressions are likely.
  - Hardcode `org-files/` in selective functions only: rejected because it creates scattered assumptions and weakens maintainability.

### 2) Constrain org-roam operations to notes root
- Decision: all node capture destinations and org-roam DB scan roots resolve from notes root (`/data/org-roam/org-files/`).
- Rationale: guarantees generated nodes land in the canonical subtree and keeps DB scope aligned with intended notes set.
- Alternatives considered:
  - Let org-roam scan repo root and filter later: rejected due to noisy indexing and unclear ownership of non-note files.

### 3) Preserve git-sync responsibility at repository root
- Decision: repository init/readiness checks and sync commands remain anchored at `/data/org-roam`.
- Rationale: git metadata and repo lifecycle belong to repository root, and `org-files/` changes are naturally included as a subtree.
- Alternatives considered:
  - Move git root to notes root: rejected because it changes repository semantics and can break existing synchronization expectations.

### 4) Centralize path derivation and validation
- Decision: use a single path-resolution layer (or helper set) consumed by URL capture, DB initialization, and git-sync modules.
- Rationale: centralization prevents drift across modules and makes future path-contract changes auditable.
- Alternatives considered:
  - Module-local constants: rejected due to duplication and higher inconsistency risk.

### 5) Align tests and docs with contract boundaries
- Decision: update integration assertions and README wording so notes destination is always `org-files/`, while sync root remains `/data/org-roam`.
- Rationale: executable assertions and docs should reinforce, not obscure, the new boundary.
- Alternatives considered:
  - Leave docs/tests unchanged and rely on code correctness: rejected because contract ambiguity would persist.

## Risks / Trade-offs

- [Partial path migration in codebase] -> Mitigation: update all path call sites via search and enforce through targeted unit/integration assertions.
- [Trailing slash / path join inconsistencies] -> Mitigation: normalize paths in one helper and avoid ad-hoc string concatenation.
- [Implicit assumptions in git-sync tests] -> Mitigation: update fixture expectations to assert repo-root behavior explicitly.
- [Operational confusion during rollout] -> Mitigation: document final path contract in README and change artifacts.

## Migration Plan

1. Add or update configuration surfaces to expose distinct notes-root and repo-root values.
2. Refactor org-roam write and DB initialization flows to consume notes root.
3. Verify git-sync initialization/readiness/sync still run from repository root.
4. Update integration assertions and docs to match the decoupled contract.
5. Run test suite and lint checks; fix regressions before apply/archive.

Rollback strategy:
- Revert the decoupling changeset and restore previous single-root behavior if blocking regressions occur.
- Because no historical-note migration is in scope, rollback is code/config only.

## Open Questions

- Should the notes root be configurable purely by environment variable, or also by a module-level default constant with override?
- Are there any external scripts (outside test harness) that still assume notes are written directly under `/data/org-roam`?
- Should we add a startup log line that prints both resolved roots to simplify operator debugging?
