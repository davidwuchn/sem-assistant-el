## Context

The project currently installs Emacs packages with `straight.el` during Docker build,
while tests run in `emacs --batch` without those packages available. This split forces
test-only package stubs and manual test bootstrapping (`load-path` setup and explicit
load ordering), adding maintenance overhead and making test behavior diverge from runtime.

This change standardizes package and test execution on Eask, using
`silex/emacs:master-alpine-ci-eask` in container builds. Eask installs dependencies into
project-local `.eask/{EMACS-VERSION}/elpa/`, preserving host isolation and avoiding
global Emacs configuration changes.

Primary stakeholders are maintainers running CI, contributors running tests locally,
and operators relying on reliable daemon behavior with no real LLM calls in unit tests.

## Goals / Non-Goals

**Goals:**
- Replace `straight.el` bootstrap with an `Eask` manifest for dependency management.
- Ensure unit tests run against real package dependencies (no package `(provide ...)` stubs).
- Simplify test invocation to Eask-native commands (`eask test ert`) with automatic
  load-path handling and test discovery.
- Keep network/DB behavior deterministic in tests by retaining functional mocks
  (`gptel`, trafilatura, org-roam) while removing package-availability scaffolding.
- Update Docker and docs so local/CI workflows share one package/test toolchain.

**Non-Goals:**
- Rewriting daemon features or changing business logic in core modules.
- Replacing the existing ERT test suite with another framework.
- Running integration tests automatically in agent workflows.
- Introducing strict lockfile-style dependency pinning beyond standard Eask constraints.

## Decisions

1. Use Eask as the single dependency manager for build and test paths.
   - Rationale: Eliminates split-brain package behavior between daemon runtime and batch tests.
   - Alternative considered: Keep `straight.el` and patch batch setup; rejected because it keeps
     test infrastructure complexity and hidden coupling to stubs.

2. Replace `bootstrap-packages.el` with a root `Eask` file.
   - Rationale: Moves package declarations to a standard ecosystem tool with simpler ergonomics.
   - Alternative considered: Keep both `bootstrap-packages.el` and `Eask`; rejected because dual
     sources of truth drift over time.

3. Switch Docker image to `silex/emacs:master-alpine-ci-eask` and run `eask install` in build.
   - Rationale: Ensures the container includes Eask-native tooling and consistent dependency install.
   - Alternative considered: Install Eask manually in current image; rejected due to extra setup,
     slower builds, and more moving parts.

4. Remove package stubs from `sem-mock.el` but keep behavioral mocks.
   - Rationale: Package stubs become redundant once real dependencies load in tests, but behavioral
     mocks remain required to avoid real network/DB access.
   - Alternative considered: Keep stubs as fallback; rejected because stale stubs can mask
     dependency regressions.

5. Standardize test entrypoints around Eask while preserving targeted ERT usage when needed.
   - Rationale: `eask test ert` should be the default for full runs; file/test-specific commands
     remain available for debugging.
   - Alternative considered: Remove all direct Emacs batch commands from docs; rejected because
     maintainers may still need lower-level invocation during troubleshooting.

## Risks / Trade-offs

- [Dependency resolution differs from pinned straight SHAs] -> Mitigation: declare explicit
  package constraints in `Eask`, run full unit suite in CI, and review updates in dependency PRs.
- [Behavior drift from removing package stubs] -> Mitigation: migrate incrementally, run full ERT
  suite after each test bootstrap change, and keep functional mocks intact.
- [Developer onboarding friction due to new tool] -> Mitigation: update README and AGENTS commands,
  including single-file and single-test examples.
- [Container build regressions after base image swap] -> Mitigation: validate Docker build and
  daemon startup logs before merge.
- [Local cache growth in `.eask/`] -> Mitigation: add `.eask/` to `.gitignore` and document cleanup.

## Migration Plan

1. Add root `Eask` with project metadata and dependencies currently expected by daemon/tests.
2. Update `Dockerfile.emacs` to use the Eask image and `eask install` during build.
3. Update `docker-compose.test.yml` to use `silex/emacs:master-alpine-ci-eask` for
   integration test compose override consistency with the new package/test toolchain.
4. Remove `bootstrap-packages.el` and replace `straight-use-package` activation paths with `require`
   in `app/elisp/init.el`.
5. Remove package stubs from `app/elisp/tests/sem-mock.el`, keeping behavioral mocks only.
6. Simplify test runner usage to Eask-driven execution and update docs (`README.md`, `AGENTS.md`).
7. Validate unit suite (`~175` ERT tests) passes without real LLM/API calls.
8. Have a human operator run integration tests manually per existing policy.

Rollback strategy:
- Revert Eask-specific files/changes and restore `bootstrap-packages.el` + previous Docker image
  if CI or daemon startup cannot be stabilized quickly.

## Open Questions

- Should we commit an optional lock artifact (if supported by current Eask workflow) for tighter
  reproducibility in CI?
- Which package version constraints are strict minimums versus permissive ranges for maintainability?
- Do we keep `sem-test-runner.el` as a thin compatibility wrapper, or remove it entirely once Eask
  commands are fully documented?
