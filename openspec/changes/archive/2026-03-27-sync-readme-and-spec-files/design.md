## Context

The change is documentation- and spec-focused: align repository documentation with the current codebase, add a clearly constrained dummy deployment guide, and reconcile OpenSpec artifacts with implemented behavior. The repository is an Emacs Lisp daemon project with operational workflows across local development, Docker/compose deployment, and OpenSpec-driven change management.

The main technical constraint is "no runtime behavior change." All updates must be descriptive, verifiable from source and scripts, and intentionally scoped to avoid introducing new feature requirements or infrastructure commitments. Another constraint is operator safety: deployment examples must remain placeholder-only and explicitly non-production.

## Goals / Non-Goals

**Goals:**
- Make README instructions match current file layout, command invocations, and operational caveats.
- Add a dummy deployment guide that demonstrates safe VPS setup flow without exposing or implying real secrets.
- Synchronize affected OpenSpec documents with implemented code paths and current behavior.
- Preserve existing intent while removing ambiguity and stale references.

**Non-Goals:**
- No code changes to daemon logic, tests, infrastructure, or runtime configuration.
- No production hardening blueprint for any specific cloud/provider.
- No new capability definitions beyond those already declared in proposal scope.

## Decisions

### 1) Evidence-first documentation updates
- **Decision:** Treat repository files and executable commands as the source of truth; update docs/specs only when directly supported by current code or scripts.
- **Rationale:** Prevents speculative or aspirational documentation drift.
- **Alternatives considered:**
  - Infer intended behavior from historical docs (rejected: may reintroduce stale guidance).
  - Expand docs proactively with suggested future architecture (rejected: violates scope).

### 2) Constrained dummy deployment section in README
- **Decision:** Add a dedicated, explicitly non-production walkthrough with placeholders, warnings, and prerequisite checks.
- **Rationale:** Gives operators an end-to-end mental model while reducing risk of accidental credential leakage or unsafe copy/paste behavior.
- **Alternatives considered:**
  - Omit deployment examples entirely (rejected: weaker onboarding).
  - Provide full production playbook (rejected: out of scope and high maintenance risk).

### 3) Capability-by-capability spec reconciliation
- **Decision:** Update OpenSpec capability files only where mismatch exists; annotate exclusions and retain original intent.
- **Rationale:** Keeps specs accurate without turning this change into a redesign effort.
- **Alternatives considered:**
  - Rewrite all specs uniformly (rejected: unnecessary churn, increased review burden).
  - Leave mismatches for later (rejected: fails change objective).

### 4) Deterministic validation checklist before completion
- **Decision:** Use a repeatable checklist: command correctness, path existence, prerequisite notes, and scope guardrails.
- **Rationale:** Improves review quality and reduces hidden regressions in docs/specs.
- **Alternatives considered:**
  - Manual ad-hoc review only (rejected: inconsistent outcomes).

## Risks / Trade-offs

- **[Risk]** Documenting current behavior may miss edge-case paths not exercised recently. **→ Mitigation:** Cross-check against source modules, scripts, and test-related instructions before finalizing.
- **[Risk]** Dummy deployment steps may be mistaken for production guidance. **→ Mitigation:** Add repeated non-production warnings, placeholder markers, and explicit hardening exclusions.
- **[Risk]** Spec alignment edits could accidentally introduce new requirements. **→ Mitigation:** Require each spec delta to map to existing implementation evidence; reject unsupported additions.
- **[Trade-off]** Tight scope avoids runtime risk but postpones improvement ideas. **→ Mitigation:** Capture deferred enhancements as explicit out-of-scope follow-ups.

## Migration Plan

1. Audit README against current repository commands, paths, and behavior.
2. Draft and insert dummy deployment guide with placeholders and prerequisite checks.
3. Identify mismatched OpenSpec capability docs and update only affected sections.
4. Run consistency pass across README, proposal/spec language, and repository structure.
5. Submit for review with a checklist proving no runtime or infra behavior changes.

Rollback strategy: revert documentation/spec commits if inconsistencies are found; no data or runtime rollback is required because executable code remains unchanged.

## Reconciliation Map

- README command/path corrections are validated against `docker-compose.yml`, `.env.example`, `crontab`, and repository root paths.
- Dummy deployment guidance is constrained to placeholder examples and references `webdav/apache/` and certbot profile behavior in `docker-compose.yml`.
- Capability wording updates are limited to this change's spec deltas and keep runtime expectations consistent with existing implementation.

## Follow-up Notes (Out of Scope)

- Add provider-specific production hardening guides (firewall, backup, secret rotation) in a separate change.
- Introduce optional helper scripts for bootstrap/logrotate setup in a separate change if operators request automation.
- Expand integration documentation around environment-specific compose tooling differences only after field feedback.

## Open Questions

- Which specific OpenSpec capability files currently diverge from implementation and need edits first?
- Should README include one canonical local/test command flow, or separate quick-start and deep-dive tracks?
- Are there existing operator conventions for naming placeholder secret/env values that should be standardized across README and specs?
