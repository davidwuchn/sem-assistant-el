## Why

Four independent correctness and reliability defects exist in the current codebase:

1. **Errors are invisible until manually checked.** Entries in `/data/errors.org` are plain Org headlines with no TODO keyword or deadline. Orgzly treats them as notes, not actionable items, and never fires a notification. A critical LLM failure at 2 AM sits silently until the user opens the file. Since `errors.org` is already synced via WebDAV, adding TODO + DEADLINE leverages the existing mobile notification infrastructure with zero new dependencies or attack surface.

2. **Sensitive content leakage is undetected at runtime.** The function `sem-security-verify-tokens-present` exists, is tested, and was explicitly designed to detect when an LLM response contains original sensitive content instead of tokens. However, it is never called in the production code path (`sem-router--route-to-task-llm`). The security-masking spec (Requirement: Token expansion detection) states the response SHALL be rejected and a CRITICAL error logged, but this is not enforced. The gap means a misbehaving LLM could write user secrets to `tasks.org` without any detection.

3. **Logging failures are completely silent.** `sem-core-log` wraps all file I/O in `condition-case` with a catch-all `(t nil)` handler. If `/data/sem-log.org` becomes unwritable (full disk, permissions, corrupted Org structure), the daemon loses its entire audit trail with no indication. The `message` fallback exists for some early-return paths but not for the general I/O failure case. Since `docker logs` captures stderr, writing to stderr on logging failure provides a zero-cost fallback that operators can monitor.

4. **Cursor hash has a delimiter collision.** Headline hashes are computed as `(secure-hash 'sha256 (concat title "|" tags "|" body))`. The pipe delimiter appears in the concatenated content, so distinct inputs can produce identical hashes. Example: title `"a|b"` + tags `"c"` + body `""` collides with title `"a"` + tags `"b|c"` + body `""`. This can cause a headline to be silently skipped as "already processed." Using structured encoding (JSON array) eliminates delimiter ambiguity.

## What Changes

- Modify `sem-core-log-error` to write `/data/errors.org` entries as `TODO` headlines with `DEADLINE` set to the current timestamp (already in the past at write time), so Orgzly surfaces them as overdue items with native notification support.
- Add a `sem-security-verify-tokens-present` call in `sem-router--route-to-task-llm` callback, after `sem-security-restore-from-llm` and before `sem-router--validate-task-response`. If the `expanded` list is non-empty, reject the response, log a CRITICAL security incident to DLQ via `sem-core-log-error`, and mark the headline as processed to prevent infinite retry with the same leaked content.
- Add stderr fallback in `sem-core-log` and `sem-core-log-error`: when the primary file write fails (caught by `condition-case`), emit a `(message "SEM-STDERR: ...")` line. The existing `dev/start-cron` message redirection ensures this reaches container stderr and `docker logs`.
- Replace pipe-delimited hash input with `(json-encode (vector title tags-str body))` in both `sem-router--parse-headlines` and `sem-core-purge-inbox`. The change is backward-incompatible: existing cursor entries will not match new hashes, so all current inbox headlines will be reprocessed once after deployment. This is acceptable because reprocessing is idempotent (DLQ or duplicate detection handles it) and the cursor file is small.
- Update all affected specifications to reflect the new behavior.

Scope boundary: this change only addresses these four defects. Out of scope: new monitoring infrastructure, external notification services (Telegram, ntfy.sh), cursor expiration/pruning, input size limits, LLM output sanitization (babel block rejection), WebDAV permission narrowing, and per-callback timeouts.

## Capabilities

### Modified Capabilities

- `structured-logging`: Error entries in `/data/errors.org` become `TODO` headlines with `DEADLINE` set to the error timestamp. The `sem-core-log` and `sem-core-log-error` functions gain stderr fallback on file I/O failure. Constraint: the TODO keyword and DEADLINE must appear in the headline and properties so that Orgzly recognizes the entry as an actionable overdue item. Constraint: stderr fallback must not itself raise errors.

- `security-masking`: The router callback in `sem-router--route-to-task-llm` SHALL call `sem-security-verify-tokens-present` on the raw LLM response before restoration. If the `expanded` list is non-empty, the response SHALL be rejected, a CRITICAL entry SHALL be written to `/data/errors.org` via `sem-core-log-error`, and the headline SHALL be marked processed. Constraint: verification runs before `sem-security-restore-from-llm` so the check operates on the raw LLM output containing tokens, not the restored text. Constraint: missing tokens (LLM dropped a token) are acceptable and do not trigger rejection.

- `inbox-processing`: Headline hash computation changes from pipe-delimited concatenation to JSON-encoded vector: `(secure-hash 'sha256 (json-encode (vector title tags-str body)))`. This affects `sem-router--parse-headlines` and any code that computes hashes for cursor comparison. Constraint: the encoding must be deterministic (JSON array with fixed key order). Constraint: all hash computation sites must use the identical formula.

- `inbox-purge`: Purge hash computation changes to match the new JSON-encoded format in `sem-router--parse-headlines`. Constraint: the hash formula in `sem-core-purge-inbox` must be identical to the router formula at all times.

## Impact

- **errors.org format change (breaking):** Existing plain headlines in `errors.org` will not retroactively gain TODO/DEADLINE. New entries will have the updated format. Old and new entries coexist in the same file without conflict since `errors.org` is append-only.
- **Cursor hash format change (breaking):** All hashes in `/data/.sem-cursor.el` become stale after deployment. On the first cron run, all inbox headlines will be reprocessed. This is a one-time cost. Reprocessing is idempotent: duplicate tasks go to DLQ, duplicate URL captures are detected by org-roam.
- **No new dependencies:** `json-encode` is built into Emacs. No new packages, services, or infrastructure.
- **No cron or deployment changes:** All changes are internal to Elisp modules.

## Affected Specifications

The following specifications require updates to reflect this change:

1. **`openspec/specs/structured-logging/spec.md`**
   - Update `errors.org` format requirement: headline becomes `TODO` with `DEADLINE`
   - Add requirement: stderr fallback when log file I/O fails
   - Update `sem-core-log-error` requirement to reflect new format

2. **`openspec/specs/security-masking/spec.md`**
   - Update "Token expansion detection" requirement: specify that verification is called in `sem-router--route-to-task-llm` callback, on raw LLM output before restoration
   - Add scenario: expanded tokens trigger DLQ entry and headline marked processed

3. **`openspec/specs/inbox-processing/spec.md`**
   - Update "Headlines parsed with org-element including body" requirement: hash formula changes to `(secure-hash 'sha256 (json-encode (vector title tags-str body)))`
   - Update "Processed node identity tracked via content hashes" requirement: note JSON encoding

4. **`openspec/specs/inbox-purge/spec.md`**
   - Update "Purge hash computation matches router format" requirement: hash formula changes to JSON-encoded vector
