## 1. Path contract and configuration

- [x] 1.1 Add a shared path-resolution helper that returns notes root (`/data/org-roam/org-files/`) and repository root (`/data/org-roam`) with normalized joining behavior.
- [x] 1.2 Wire startup configuration to set org-roam note operations from notes root and keep git lifecycle values bound to repository root.
- [x] 1.3 Add startup/runtime logging that clearly reports both resolved roots for operator debugging.

## 2. Org-roam write and DB lifecycle updates

- [x] 2.1 Refactor URL-capture node destination logic to always write new node files under notes root and never under repo-root top level.
- [x] 2.2 Update org-roam DB initialization/sync call sites to index `.org` files from notes root and preserve existing delete-and-rebuild behavior for DB files.
- [x] 2.3 Verify daemon write contract remains append-only for note creation (no modification/deletion of existing note files).

## 3. Git readiness and sync boundary enforcement

- [x] 3.1 Ensure repository readiness checks still test for `.git` under `/data/org-roam` and run `git init` only at repository root when missing.
- [x] 3.2 Confirm scheduled git sync operations execute from repository root and continue to include `org-files/` subtree changes.
- [x] 3.3 Add or adjust targeted tests that fail if git responsibilities move to notes root or if note writes target repo-root top level.

## 4. Assertions, docs, and verification

- [x] 4.1 Update integration assertion logic/constants so trusted URL-capture node validation explicitly requires paths under `/data/org-roam/org-files/`.
- [x] 4.2 Update README path contract documentation to describe notes root vs repository root responsibilities and remove stale top-level note destination references.
- [x] 4.3 Run ERT test suite and elisp lint checks for touched modules; resolve regressions and capture any follow-up gaps.
