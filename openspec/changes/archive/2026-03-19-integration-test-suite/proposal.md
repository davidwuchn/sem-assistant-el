## Why

The daemon has no end-to-end test coverage. Unit tests mock all external calls. There is no
automated way to verify that a real inbox headline flows through the full pipeline (WebDAV upload →
Emacs LLM processing → tasks.org write → WebDAV retrieval) and produces a valid, parseable Org file.
This gap makes regressions invisible until production breaks.

## What Changes

A new self-contained integration test suite is added under `dev/integration/`. It spins up the full
container stack using `podman-compose`, uploads a real test inbox via HTTP to WebDAV, triggers
inbox processing directly via `emacsclient`, polls for output, collects all artifacts, runs
assertions, and tears down unconditionally. Real LLM calls are made via OpenRouter. The suite is
**never run automatically**; it requires explicit operator invocation.

## Capabilities

### New Capabilities

- `integration-test-runner`: A single Bash script `dev/integration/run-integration-tests.sh` that
  executes the full integration test lifecycle. Constraints:
  - Requires `OPENROUTER_KEY` env var set; fails immediately with a clear error message if absent.
  - Uses `podman-compose` and `podman` exclusively. Docker must not be referenced or used.
  - Script is invoked from the repository root: `bash dev/integration/run-integration-tests.sh`.
    No arguments are accepted. All configuration is via environment variables or hardcoded constants
    within the script.
  - A `trap ... EXIT` block is the FIRST thing registered after argument validation. It must run
    `podman-compose -f docker-compose.yml -f dev/integration/docker-compose.test.yml down -v`
    unconditionally, regardless of pass/fail/signal. This is non-negotiable.
  - `set -euo pipefail` is set at the top of the script.
  - Every `podman` / `curl` / `emacs --batch` command that can fail must have its exit code
    checked. Do not swallow errors with `|| true` unless the specific silent-failure is documented
    inline with a comment.

- `test-compose-override`: `dev/integration/docker-compose.test.yml` — a Compose override file
  (not a standalone compose file). Constraints:
  - Overrides `webdav` service: replaces volume mount of `webdav-config.yml` with
    `dev/integration/webdav-config.test.yml`; removes the `/etc/letsencrypt:/certs:ro` volume;
    changes port mapping to `16065:6065`; sets `restart: "no"`.
  - Overrides `emacs` service: removes the `~/.ssh/vps-org-roam:/root/.ssh:ro` volume mount;
    sets `restart: "no"`.
  - Both services: overrides the `./data:/data:rw` volume binding to `./test-data:/data:rw`.
  - Both services: overrides the `./logs:/var/log/sem:rw` volume binding to keep `./logs` path
    (logs/ is wiped by the script at run start, not changed in compose).
  - Does NOT redefine image, build context, environment vars, or depends_on — those are inherited
    from `docker-compose.yml`.

- `test-webdav-config`: `dev/integration/webdav-config.test.yml` — WebDAV config for tests.
  Constraints:
  - `server.port: 6065` (same as production, mapped differently at host level).
  - `server.tls: false` — explicit key, not omitted.
  - No `cert` or `key` keys present.
  - Users block identical to production (`{env}WEBDAV_USERNAME`, `{env}WEBDAV_PASSWORD`, scope
    `/data`, all permissions). Credentials are still sourced from environment variables so the
    `.env` file is still used.

- `test-inbox-resource`: `dev/integration/testing-resources/inbox-tasks.org` — the org file
  uploaded as the test inbox. Constraints:
  - Exactly 3 headlines, each tagged `@task`. One `:routine:`, one `:work:`, one bare `@task`
    (no secondary tag — tests the default-tag normalization path).
  - The third headline must have a body (multi-line text below the headline) to exercise body
    extraction.
  - Titles must be unique enough that grep assertions are unambiguous (no single-word titles like
    "Test").
  - No `@link` headlines. URL capture is explicitly out of scope for this suite.

- `run-dir-artifacts`: A timestamped directory `test-results/YYYY-MM-DD:HH:MM:SS-run/` created
  at script start. Constraints:
  - `test-results/` is created if absent; it is git-ignored.
  - The run directory name uses the format produced by `date +%Y-%m-%d:%H:%M:%S`.
  - Files collected into run dir (all collected unconditionally, missing files noted but do not
    abort collection):
    - `inbox-sent.org` — copy of `dev/integration/testing-resources/inbox-tasks.org`
    - `tasks.org` — GET from `http://localhost:16065/tasks.org`
    - `sem-log.org` — GET from `http://localhost:16065/sem-log.org`
    - `errors.org` — GET from `http://localhost:16065/errors.org` (may 404 — skip silently)
    - `messages-*.log` — copied from `./logs/` using glob; preserve filenames
    - `emacs-container.log` — `podman logs sem-emacs 2>&1`
    - `webdav-container.log` — `podman logs sem-webdav 2>&1`
    - `validation.txt` — stdout + stderr of all assertion steps (tee'd during assertions)
  - Artifact collection runs BEFORE containers are stopped (trap fires after collection).
  - If GET for `tasks.org` returns HTTP non-200 (e.g., timed out and file never created), save an
    empty placeholder and note the failure in `validation.txt`.

- `daemon-ready-poll`: Script waits for the Emacs daemon to accept connections before proceeding.
  Constraints:
  - Command: `podman exec sem-emacs emacsclient -e "t"` (returns "t" on success).
  - Poll interval: 3 seconds.
  - Maximum attempts: 30 (= 90 seconds total).
  - On exhaustion: print error to stderr, set FAIL status, proceed directly to artifact collection
    and exit 1.

- `inbox-upload`: Script uploads the test inbox via HTTP PUT to WebDAV. Constraints:
  - Command: `curl --fail --silent --show-error -u "${WEBDAV_USERNAME:-orgzly}:${WEBDAV_PASSWORD:-changeme}" -T dev/integration/testing-resources/inbox-tasks.org http://localhost:16065/inbox-mobile.org`
  - `--fail` ensures non-2xx HTTP responses cause curl to exit non-zero.
  - If curl exits non-zero, script aborts immediately (set -e handles this).

- `inbox-trigger`: Script triggers inbox processing synchronously. Constraints:
  - Command: `podman exec sem-emacs emacsclient -e "(sem-core-process-inbox)"`.
  - If this command exits non-zero, script aborts immediately. No retries.
  - This call returns before LLM callbacks complete. The poll step handles async completion.

- `tasks-poll`: Script polls for `tasks.org` to contain all 3 expected TODO entries. Constraints:
  - Poll interval: 5 seconds.
  - Maximum wait: 120 seconds (24 attempts).
  - Completion criterion: `tasks.org` fetched via HTTP GET returns HTTP 200 AND contains exactly
    3 lines matching the pattern `^\* TODO ` (grep -c).
  - Implementation: each iteration GETs `tasks.org` to a temp file, counts matching lines, stops
    when count >= 3.
  - On timeout: set FAIL status, proceed to artifact collection. Do NOT abort with set -e here —
    use explicit status variable.
  - The temp file from the last successful GET is used as the authoritative `tasks.org` artifact.

- `assertions`: All assertions run after artifact collection. Their output is tee'd to
  `validation.txt`. Constraints:
  - **Assertion 1 — TODO count**: `grep -c '^\* TODO ' tasks.org` must equal 3. Failure message:
    `FAIL: expected 3 TODO entries, got N`.
  - **Assertion 2 — keyword presence**: `grep` for each of the 3 headline title keywords (one per
    headline) in `tasks.org`. Each must match. Failure message names the missing keyword.
  - **Assertion 3 — Org validity**: Run:
    ```
    emacs --batch \
      --eval "(condition-case err \
                (progn (find-file \"RUN_DIR/tasks.org\") \
                       (org-mode) \
                       (org-element-parse-buffer) \
                       (message \"ORG-VALID\")) \
              (error (error \"ORG-INVALID: %s\" err)))"
    ```
    Exit code 0 = valid. Non-zero = invalid. Failure message: `FAIL: tasks.org is not valid Org`.
  - All 3 assertions run even if one fails (do not short-circuit). Final exit code is 1 if any
    assertion failed, 0 if all passed.

- `exit-behavior`: Script exit semantics. Constraints:
  - Exit 0: all assertions passed.
  - Exit 1: any assertion failed, timeout reached, daemon never ready, or emacsclient trigger
    failed.
  - Artifact collection always runs before exit (trap order: collect → down).
  - `test-data/` is NOT deleted on exit. It remains on disk for post-mortem inspection. It is
    wiped at the START of the next run.
  - `logs/` is wiped and recreated at script START (before compose up), not at exit.

- `test-data-isolation`: The `./test-data/` directory is the ephemeral data volume for tests.
  Constraints:
  - At script start: delete `./test-data/` entirely if it exists, then recreate with subdirs:
    `test-data/org-roam`, `test-data/elfeed`, `test-data/morning-read`, `test-data/prompts`.
  - `test-data/` is git-ignored.
  - `test-data/` is NOT the production `./data/` directory. The script must never touch `./data/`.

- `agents-md-warning`: A new section added to `AGENTS.md` explicitly forbidding agents from
  running the integration tests. Constraints:
  - Section title: `## Integration Tests — DO NOT RUN`.
  - Must state: agents must never execute `dev/integration/run-integration-tests.sh` or any
    `podman-compose` command referencing `docker-compose.test.yml`.
  - Must state: integration tests make real LLM API calls that cost money.
  - Must state: only the human operator runs integration tests.

- `readme-integration-section`: A new section added to `README.md` documenting the integration
  test suite. Constraints:
  - Section title: `## Integration Tests`.
  - Must note that `podman` and `podman-compose` are required (not Docker).
  - Must document: `OPENROUTER_KEY` must be set.
  - Must document the exact invocation command from repo root.
  - Must document where results are saved (`test-results/`).
  - Must warn that real LLM API calls are made and incur cost.
  - Must include the explicit note: **DO NOT RUN this script unless you intend to make real API
    calls.** Operator runs it manually; it is never run automatically.

### Modified Capabilities

- `gitignore`: `.gitignore` must be updated to ignore `test-results/` and `test-data/`. If no
  `.gitignore` exists, create one. These two entries must be added regardless of what else is
  present.

## Impact

- No changes to any production Elisp source files.
- No changes to `docker-compose.yml`, `webdav-config.yml`, `crontab`, or `Dockerfile.emacs`.
- New files are additive only, under `dev/integration/` and repository root docs.
- Running the test suite consumes OpenRouter API credits (3 LLM calls per run).
- `test-data/` and `test-results/` directories will appear at repository root after first run.
  Both are git-ignored.
- `podman` and `podman-compose` must be installed on the operator's machine. This is a
  prerequisite, not something the script installs.
