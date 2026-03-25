## Context

WebDAV currently expects certificate and key files to already exist under `/etc/letsencrypt/live/${WEBDAV_DOMAIN}/` and serves HTTPS directly from those files. This creates a manual certificate lifecycle burden and renewal risk. The change introduces Certbot HTTP-01 automation for production while keeping integration tests non-TLS and isolated from certificate issuance.

The current repository has separate production and integration compose flows. The integration path intentionally runs WebDAV without TLS and must remain independent from public DNS, inbound port 80 reachability, and host-level Let's Encrypt state.

## Goals / Non-Goals

**Goals:**
- Add a production-only Certbot HTTP-01 path that can issue and renew certificates for `WEBDAV_DOMAIN`.
- Keep WebDAV as the TLS termination point (no reverse proxy migration).
- Preserve deterministic integration tests that do not require Certbot, TLS cert files, or challenge networking.
- Define explicit startup and failure behavior when certificate material is missing, invalid, or stale.

**Non-Goals:**
- Implement DNS-01 or wildcard certificate support.
- Move TLS termination to a separate proxy layer.
- Convert integration tests to HTTPS.
- Change inbox/LLM daemon behavior outside WebDAV/TLS operational paths.

## Decisions

1. Production certificate lifecycle is managed by Certbot with HTTP-01 challenge on port 80.
   - **Why:** Matches proposal requirements and avoids DNS provider coupling.
   - **Alternative considered:** DNS-01. Rejected because it adds DNS API credential handling and is out of scope.

2. Certificate source of truth remains the existing Let's Encrypt live-path consumed by WebDAV.
   - **Why:** Preserves current WebDAV HTTPS configuration model and minimizes app-level changes.
   - **Alternative considered:** Copy certs into app-specific paths. Rejected due to duplication, rotation drift risk, and extra permission handling.

3. Production and test runtime states are explicitly isolated.
   - **Why:** Prevents test workflows from depending on external DNS/network conditions and avoids accidental mutation of production certificate state.
   - **Alternative considered:** Shared compose fragments with runtime flags. Rejected because it increases accidental coupling risk and reduces clarity.

4. Startup behavior is fail-fast in production when TLS is enabled but required cert/key files are missing or unreadable.
   - **Why:** Prevents silently degraded security posture and makes operator remediation immediate.
   - **Alternative considered:** Automatic downgrade to HTTP. Rejected because it can unintentionally expose services without TLS.

5. Operator configuration is explicit for domain and certificate contact/environment.
   - **Why:** Certificate issuance is sensitive to domain, email, and environment (staging vs production), so behavior must be intentional and observable.
   - **Alternative considered:** Implicit defaults only. Rejected because ambiguous defaults make issuance failures harder to diagnose.

## Risks / Trade-offs

- [Port conflicts on 80/443] -> Mitigation: document required bindings clearly; fail with actionable logs when ports are unavailable.
- [DNS or firewall misconfiguration blocks HTTP-01] -> Mitigation: preflight validation guidance and explicit issuance/renew logs for operator triage.
- [Renewal succeeds but service does not pick up updated files] -> Mitigation: define reload/restart operational step and verify cert expiry in post-renew checks.
- [File permissions or SELinux context prevent WebDAV from reading cert files] -> Mitigation: document required ownership/labels and include startup validation with clear error output.
- [Test environment accidentally references production cert paths] -> Mitigation: keep test compose override non-TLS and assert no cert-path dependency in integration setup.

## Migration Plan

1. Add production Certbot service/configuration and environment variables for domain/contact/staging behavior.
2. Wire WebDAV production startup checks to validate expected cert/key paths before serving HTTPS.
3. Keep integration compose override explicitly non-TLS with no Certbot dependency.
4. Deploy in staging mode first (Let's Encrypt staging endpoint) to validate challenge flow without rate-limit risk.
5. Switch to production issuance, verify certificate presence/expiry, and run WebDAV TLS health validation.

Rollback strategy:
- Disable Certbot automation and restore previous manual certificate provisioning path.
- Keep WebDAV pointed at known-good cert/key material.
- Re-run service startup checks and WebDAV TLS verification.

## Open Questions

- Should renewal-triggered WebDAV reload be implemented as a direct hook or handled by periodic service restart policy?
- What minimum logging/alerting channel is required for renewal failures in this deployment (stdout logs only vs external notification)?
- Do we need an explicit preflight command/script for operators to validate DNS and port 80 reachability before first issuance?
