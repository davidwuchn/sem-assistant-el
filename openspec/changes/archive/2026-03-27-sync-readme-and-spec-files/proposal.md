## Why

README and spec artifacts have drift risk versus the current codebase, which increases onboarding time and causes operator mistakes during deployment and maintenance.

## What Changes

- Update README to match actual behavior, commands, and repository structure.
- Add a dummy how-to-deploy guide in README that documents a safe, non-production example flow for VPS setup.
- Reconcile OpenSpec files with current code where mismatches exist.
- Explicitly define non-goals to prevent accidental scope expansion into implementation or infrastructure changes.

## Capabilities

### New Capabilities

- `dummy-deploy-guide`: README includes an end-to-end dummy deployment guide with explicit constraints: podman/podman-compose install steps for VPS, certbot setup flow, required environment variable/password locations, placeholder-only secret examples, and clear warnings that no real credentials, domains, or provider-specific production hardening are included.

### Modified Capabilities

- `readme-accuracy`: README content is aligned to current code paths, commands, and operational behavior; remove stale references, keep examples executable or clearly marked as illustrative, and document edge cases for missing tools, missing env vars, and certificate renewal prerequisites.
- `spec-code-alignment`: Existing OpenSpec files are updated only when they mismatch the implemented code; preserve intent, avoid introducing new requirements, and mark out-of-scope items explicitly (no feature additions, no refactors, no runtime behavior changes).

## Impact

- Improves operator confidence and junior-model reliability by reducing ambiguity in docs and specs.
- Low implementation risk: documentation/spec-only change, no functional runtime modifications.
- Validation focus: consistency checks across README, OpenSpec artifacts, and current source tree.
