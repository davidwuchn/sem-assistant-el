## 1. Test Infrastructure Setup

- [x] 1.1 Create directory structure: `dev/integration/` and `dev/integration/testing-resources/`
- [x] 1.2 Create `dev/integration/docker-compose.test.yml` compose override file
- [x] 1.3 Create `dev/integration/webdav-config.test.yml` WebDAV config for tests
- [x] 1.4 Create test inbox file `dev/integration/testing-resources/inbox-tasks.org` with 3 headlines
- [x] 1.5 Update `.gitignore` to include `test-results/` and `test-data/`

## 2. Test Runner Script

- [x] 2.1 Create `dev/integration/run-integration-tests.sh` with `set -euo pipefail`
- [x] 2.2 Add OPENROUTER_KEY validation (fail immediately if not set)
- [x] 2.3 Register EXIT trap for cleanup: `podman-compose down -v`
- [x] 2.4 Implement test data directory setup (wipe and recreate subdirs)
- [x] 2.5 Implement logs directory wipe at start

## 3. Container Lifecycle

- [x] 3.1 Start containers with `podman-compose -f docker-compose.yml -f dev/integration/docker-compose.test.yml up -d`
- [x] 3.2 Implement daemon readiness poll (emacsclient -e "t", 3s interval, 30 max attempts)
- [x] 3.3 Handle daemon timeout: print error, set FAIL, proceed to artifact collection

## 4. Inbox Processing

- [x] 4.1 Implement inbox upload via curl HTTP PUT to WebDAV
- [x] 4.2 Implement inbox trigger via emacsclient `(sem-core-process-inbox)`
- [x] 4.3 Implement tasks poll (5s interval, 120s max, grep for 3 TODO entries)
- [x] 4.4 Handle poll timeout: set FAIL, save partial results, proceed to collection

## 5. Artifact Collection

- [x] 5.1 Create timestamped run directory `test-results/YYYY-MM-DD:HH:MM:SS-run/`
- [x] 5.2 Copy inbox-sent.org to run directory
- [x] 5.3 GET tasks.org from WebDAV, save to run directory
- [x] 5.4 GET sem-log.org from WebDAV, save to run directory
- [x] 5.5 GET errors.org from WebDAV (handle 404 silently)
- [x] 5.6 Copy log files from `./logs/messages-*.log`
- [x] 5.7 Collect container logs: `podman logs sem-emacs` and `podman logs sem-webdav`
- [x] 5.8 Implement validation.txt with tee'd assertion output

## 6. Assertions

- [x] 6.1 Implement TODO count assertion (grep -c '^\* TODO ' must equal 3)
- [x] 6.2 Implement keyword presence assertion (grep for each headline keyword)
- [x] 6.3 Implement Org validity assertion (emacs --batch with org-element-parse-buffer)
- [x] 6.4 Ensure all assertions run (no short-circuit on failure)
- [x] 6.5 Set exit code 0 if all pass, 1 if any fail

## 7. Documentation Updates

- [x] 7.1 Add "## Integration Tests — DO NOT RUN" section to AGENTS.md
- [x] 7.2 Add "## Integration Tests" section to README.md with usage instructions

## 8. Verification

- [x] 8.1 Run elisplint.sh on any new elisp files (if applicable)
- [x] 8.2 Verify all files are in correct locations per spec
- [x] 8.3 Verify .gitignore entries are correct