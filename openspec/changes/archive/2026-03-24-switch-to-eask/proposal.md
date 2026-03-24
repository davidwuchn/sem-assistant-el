## Why

The project uses `straight.el` to install packages at Docker build time, but these packages are unavailable in `emacs --batch` test mode. This forces a parallel mock infrastructure: fake `(provide pkg)` stubs for 5 packages, a hand-written `gptel-request` placeholder, manual `load-path` setup, and explicit `load-file` ordering for 13 test files. Switching to Eask eliminates the fake-package layer, gives tests access to real dependencies, simplifies the test runner, and standardizes the build/test toolchain. The `silex/emacs:master-alpine-ci-eask` Docker image is available.

## What Changes

- **BREAKING**: Replace `straight.el` with Eask for package management (build-time and test-time)
- **BREAKING**: Replace `bootstrap-packages.el` with an `Eask` file declaring dependencies
- **BREAKING**: Change Docker base image from `silex/emacs:master-alpine-ci` to `silex/emacs:master-alpine-ci-eask`
- Remove package stubs from `sem-mock.el` (the `(provide pkg)` block and `gptel-request` stub function); keep all functional mocks (gptel, trafilatura, org-roam) for network/DB isolation
- Replace manual `sem-test-runner.el` with `eask test ert` (auto-discovers test files, sets up load-path)
- Update `init.el` to use `require` instead of `straight-use-package` for load-path activation
- Update `Dockerfile.emacs` to run `eask install` instead of `emacs --batch --load bootstrap-packages.el`
- Add `.eask/` to `.gitignore` (Eask installs packages into `.eask/{EMACS-VERSION}/elpa/` locally, fully isolated from the developer's `~/.emacs.d/`)
- Update `README.md`: Quick Start, File Structure, and developer setup sections
- Update `AGENTS.md`: test commands (how to run all tests, single file, single test), repository layout, mock usage documentation
- All existing unit tests (~175 ERT tests) must pass with no real LLM calls
- Integration tests must pass (run manually by human operator, not by agent)

## Capabilities

### New Capabilities
- `eask-package-management`: Eask-based dependency declaration and installation, replacing straight.el bootstrap. Packages install into project-local `.eask/{EMACS-VERSION}/elpa/`, fully isolated from the developer's system Emacs (`~/.emacs.d/` is never touched).

### Modified Capabilities
- `emacs-package-provisioning`: Package provisioning switches from straight.el to Eask; Dockerfile build step changes from `emacs --batch --load bootstrap-packages.el` to `eask install`; init.el activation changes from `straight-use-package` to `require`
- `integration-test-runner`: Docker base image changes to `silex/emacs:master-alpine-ci-eask` in test compose override

## Impact

- **Dockerfile.emacs**: Base image change to `silex/emacs:master-alpine-ci-eask`, build step change (`eask install` replaces `emacs --batch --load bootstrap-packages.el`)
- **Eask** (new file at project root): Project metadata and dependency declarations
- **app/elisp/bootstrap-packages.el**: Removed (replaced by `Eask` file)
- **app/elisp/init.el**: `straight-use-package` calls replaced with `require` (packages on load-path via Eask)
- **app/elisp/tests/sem-mock.el**: Package stubs (lines 12-29) removed; functional mocks unchanged
- **app/elisp/tests/sem-test-runner.el**: Simplified or removed (Eask handles test discovery and load-path)
- **docker-compose.test.yml**: Base image reference updated
- **.gitignore**: Add `.eask/` entry
- **README.md**: Setup instructions, file structure, test commands updated
- **AGENTS.md**: Test commands, repository layout, mock documentation updated
- **Dependency pinning**: Moves from exact git commit SHAs to MELPA version constraints (trade-off: less precise pinning, simpler management)
