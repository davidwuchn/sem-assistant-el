## Context

The Docker build process installs Emacs packages via straight.el into the container image. These packages are available at build time, but when the Emacs daemon starts later, it runs in a fresh process where straight.el's `load-path` modifications from the build are not preserved. The current `init.el` calls `(require ...)` for all package modules, but those modules are not on `load-path` at daemon startup because `straight-use-package` was never called to activate them.

The `emacs-package-provisioning` spec currently mandates "no runtime package installation" and "`init.el` only calls `(require ...)`, never `straight-use-package`". This design revises that constraint to permit `straight-use-package` calls that only activate pre-built packages without network access.

## Goals / Non-Goals

**Goals:**
- Make build-time-installed packages visible to the Emacs daemon at runtime via `load-path`
- Maintain the constraint that `init.el` must not download or install packages over the network
- Preserve the separation of concerns: bootstrap-packages.el handles installation, init.el handles activation

**Non-Goals:**
- Installing new packages at runtime
- Modifying straight.el's build-time recipe definitions
- Supporting package managers other than straight.el

## Decisions

### 1. Use `straight-use-package` for activation, not installation

**Decision:** Call `straight-use-package` in `init.el` for each pre-built package after straight.el is bootstrapped.

**Rationale:** `straight-use-package` is the canonical way to register packages with straight.el. When called with a package that is already built (cache exists), it adds the package to `load-path` without network access. Using `(add-to-list 'load-path ...)` directly would bypass straight.el's bookkeeping and could cause issues with future `straight-use-package` calls.

**Alternative considered:** Direct `(add-to-list 'load-path ...)` calls pointing to the built package directories. Rejected because it sidesteps straight.el's package registry and could cause inconsistencies if straight.el's layout assumptions change.

### 2. Package activation after straight.el bootstrap

**Decision:** Activate packages in `sem-init--bootstrap-straight` after `straight.el` itself is bootstrapped.

**Rationale:** straight.el must be fully initialized before it can activate other packages. The bootstrap sequence ensures straight.el's core is functional before any package activation occurs.

**Alternative considered:** Separate function `sem-init--activate-packages`. Rejected to keep activation logic co-located with the bootstrap sequence it depends on.

### 3. No network access during activation

**Decision:** Activation assumes all packages are pre-built and cached. No network calls are made.

**Rationale:** The Docker build process installs packages; runtime only activates them. Network access in the daemon is a security concern and unnecessary for this use case.

## Risks / Trade-offs

- **[Risk] Package not found at runtime** → If a package was installed at build time but the cache is somehow cleared, `straight-use-package` will attempt to rebuild it. Mitigation: Ensure Docker image layers preserve the straight.el cache, or document this as a known constraint.
- **[Risk] Order dependency** → Activation must happen after straight.el bootstrap. Current structure enforces this, but future refactoring could break it. Mitigation: Keep activation in `sem-init--bootstrap-straight`; do not move to a separate initialization phase.
- **[Risk] Spec violation perception** → The spec change permits `straight-use-package` in `init.el`, which could be misinterpreted as allowing package installation. Mitigation: Document clearly that only activation (no network, no download) is permitted.

## Open Questions

1. Should `straight-use-package` failures at daemon startup be logged as errors or silently ignored? Currently not handled—this design assumes all packages are pre-built and will activate successfully. ANSWER: should be logged as errors
2. Is there a need to detect and skip already-activated packages to avoid redundant work? straight.el may handle this internally, but worth verifying. ANSWER: should work out-of-the box; if not will be a part of the follow-up change, not this one
