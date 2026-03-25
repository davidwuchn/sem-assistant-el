## Why

WebDAV TLS currently depends on pre-provisioned host certificates under `/etc/letsencrypt`, which creates manual certificate lifecycle work and renewal risk. We need automatic certificate issuance and renewal using Certbot while preserving the existing integration-test flow that intentionally runs non-TLS WebDAV on a test port.

## What Changes

- Introduce an optional Certbot capability for production using HTTP-01 challenge on port 80.
- Preserve the existing WebDAV TLS termination model (WebDAV serves HTTPS directly from cert/key files).
- Keep integration tests independent from Certbot and TLS issuance requirements.
- Add explicit operator configuration for domain and certificate contact/behavior.
- Define strict failure behavior so certificate issuance/renewal problems do not silently break test workflows.

## Capabilities

### New Capabilities

- `certbot-http01-webdav-tls`: Automatic certificate issuance/renewal is supported via Certbot HTTP-01 challenge endpoint on port 80, with explicit constraints: public DNS must resolve to the host, inbound TCP/80 must be reachable for challenge validation, the configured domain must match the WebDAV TLS certificate path, and production certificate state must be isolated from integration test state.

### Modified Capabilities

- `webdav-tls-config`: WebDAV TLS configuration remains domain-driven (`WEBDAV_DOMAIN`) and cert-path compatible with Let's Encrypt, but now explicitly supports Certbot-managed lifecycle as the primary source of certificates; startup behavior must be defined for missing/invalid cert files.
- `test-compose-override`: Integration override must continue to bypass production TLS dependencies; test compose behavior must explicitly exclude any requirement for Certbot issuance, challenge port 80, or host-level Let's Encrypt state.
- `test-webdav-config`: Test WebDAV must remain non-TLS (`tls: false`) and continue to run without cert/key material so integration flow is deterministic and cost/scenario boundaries remain unchanged.

## Impact

- Operator-facing configuration surface increases (domain/email/staging/renewal-related settings), and invalid values can block certificate issuance.
- Port binding constraints become stricter in production (port 80 for HTTP-01 and 443 for HTTPS) and may conflict with existing services or firewalls.
- TLS continuity risk shifts from manual renewal to automation correctness; renewal timing, challenge reachability, and file-permission/SELinux context issues must be treated as first-class edge cases.
- Non-goals (out of scope): DNS-01 flow, wildcard certificates, integration tests over HTTPS, changes to LLM/inbox pipeline behavior, and introducing reverse-proxy termination architecture.
