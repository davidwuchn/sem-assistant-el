## Why

The current org-roam flow assumes a single root (`/data/org-roam`) for both note storage and git synchronization. The second-brain repository uses `org-files/` as the canonical notes subtree, so new SEM-generated nodes can land in the wrong location and be excluded from downstream workflows that read only `org-files/`.

## What Changes

Decouple org-roam notes directory from git repository root in configuration and behavior.

Set canonical notes root to `/data/org-roam/org-files/` for org-roam operations, while keeping git synchronization repository root at `/data/org-roam`.

Update all relevant specs, integration test expectations, and README path contracts to consistently reflect this split.

## Capabilities

### New Capabilities

- `org-roam-notes-repo-root-decoupling`: The system supports separate canonical paths for notes (`/data/org-roam/org-files/`) and git repository root (`/data/org-roam`) with explicit, non-overlapping responsibilities. Constraint: all org-roam node creation and org-roam DB generation target notes root only. Constraint: git sync stages and pushes from repository root only.

### Modified Capabilities

- `url-capture`: New org-roam nodes are written under `/data/org-roam/org-files/` and never to `/data/org-roam` top-level.
- `db-initialization`: org-roam DB lifecycle is bound to notes root (`/data/org-roam/org-files/`) and preserves repository-root separation.
- `github-sync-readiness`: git repository initialization and readiness checks remain at `/data/org-roam`, independent of notes root.
- `github-sync`: synchronization continues at repository root (`/data/org-roam`) and must include notes subtree changes under `org-files/`.
- `assertions`: integration assertions that validate org-roam outputs are updated to treat `org-files/` as canonical notes location.
- `documentation-path-contract`: README path references are normalized to the decoupled model and must not describe `/data/org-roam` as the note file destination.

## Impact

Eliminates path mismatch between runtime behavior and second-brain repository layout.

Prevents silent divergence where generated notes are created outside the canonical notes subtree.

Adds explicit scope boundaries:
- In scope: path contract changes for org-roam flow, git-sync root retention, spec updates, integration test updates, README updates.
- Out of scope: migration or relocation of existing historical notes, repository restructuring, changes to task routing (`tasks.org`), and UI/workflow logic unrelated to path resolution.
