## 1. Eask foundation

- [x] 1.1 Add a root `Eask` file declaring required dependencies (`gptel`, `elfeed`, `elfeed-org`, `org-roam`, `websocket`).
- [x] 1.2 Add `.eask/` to `.gitignore` to keep local Eask installs out of version control.

## 2. Build and runtime provisioning migration

- [x] 2.1 Update `Dockerfile.emacs` to use `silex/emacs:master-alpine-ci-eask`.
- [x] 2.2 Replace the build-time package install step with `eask install` and ensure build fails on install errors.
- [x] 2.3 Remove `app/elisp/bootstrap-packages.el` from the codebase.
- [x] 2.4 Update `app/elisp/init.el` to load dependencies via `require` (no `straight-use-package` path activation).

## 3. Test harness alignment

- [x] 3.1 Remove package `(provide ...)` stubs and the package-availability `gptel-request` placeholder from `app/elisp/tests/sem-mock.el` while keeping behavioral mocks.
- [x] 3.2 Replace or simplify manual `app/elisp/tests/sem-test-runner.el` usage so full unit tests run via `eask test ert`.
- [x] 3.3 Update any local/CI test invocation scripts or docs that still assume manual `load-path` bootstrapping.

## 4. Integration test environment consistency

- [x] 4.1 Update `docker-compose.test.yml` to use `silex/emacs:master-alpine-ci-eask` for the Emacs service.
- [x] 4.2 Verify integration test environment assumptions remain valid with Eask-enabled image configuration (without running paid integration tests as agent).

## 5. Documentation and validation

- [x] 5.1 Update `README.md` quick-start, repository layout, and test command sections for Eask-based workflows.
- [x] 5.2 Update `AGENTS.md` commands and testing guidance to reflect Eask and revised mock expectations.
- [x] 5.3 Run the full unit test suite via `eask test ert` and confirm existing tests pass without real LLM/API calls.
- [x] 5.4 Have a human operator run `bash dev/integration/run-integration-tests.sh` and record a passing result before considering the change complete.
