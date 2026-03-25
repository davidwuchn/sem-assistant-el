## 1. Certbot HTTP-01 Lifecycle

- [x] 1.1 Add production Certbot service/configuration to request certificates for `WEBDAV_DOMAIN` via HTTP-01 on port 80.
- [x] 1.2 Ensure certificate issuance failures (DNS/port-80 precondition issues) are surfaced with actionable logs.
- [x] 1.3 Implement renewal automation that preserves the existing live-path contract used by WebDAV.

## 2. WebDAV TLS Path and Startup Validation

- [x] 2.1 Update WebDAV TLS certificate path usage to `fullchain.pem` and `privkey.pem` under `/certs/live/{env}WEBDAV_DOMAIN/`.
- [x] 2.2 Add and document `WEBDAV_DOMAIN` in `.env.example` with clear certificate-domain guidance.
- [x] 2.3 Add fail-fast startup checks for missing, unreadable, or invalid certificate material when TLS is enabled.

## 3. Integration-Test Isolation

- [x] 3.1 Update `dev/integration/docker-compose.test.yml` to remove production Let's Encrypt dependency and mount test cert assets only.
- [x] 3.2 Ensure test compose overrides set `restart: "no"`, redirect data mounts to `./test-data`, and preserve logs mounts.
- [x] 3.3 Confirm test compose flow has no Certbot service or HTTP-01 challenge dependency.

## 4. Test WebDAV Non-TLS Configuration

- [x] 4.1 Ensure `dev/integration/webdav-config.test.yml` sets `server.tls: false` and `server.port: 6065`.
- [x] 4.2 Remove TLS `cert`/`key` keys from test WebDAV config and keep env-based credentials/scopes.
- [x] 4.3 Verify test WebDAV startup remains deterministic without `/etc/letsencrypt`, DNS, or port-80 reachability assumptions.

## 5. Validation and Operator Rollout

- [x] 5.1 Validate production issuance in staging mode first, then verify production issuance and certificate expiry visibility.
- [x] 5.2 Verify renewal updates are picked up by WebDAV using the defined reload/restart operational procedure.
- [x] 5.3 Document operator troubleshooting for port conflicts, DNS misconfiguration, and certificate permission issues.
