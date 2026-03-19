## 1. Modify init.el to activate build-time-installed packages

- [x] 1.1 Identify the list of packages installed at build time (gptel, elfeed, elfeed-org, org-roam, websocket)
- [x] 1.2 Add `straight-use-package` calls for each package in `sem-init--bootstrap-straight` after straight.el bootstrap
- [x] 1.3 Wrap each `straight-use-package` call in `condition-case` to log errors without crashing the daemon
- [x] 1.4 Verify straight.el activation completes before package activation attempts

## 2. Verify no network access at runtime

- [x] 2.1 Confirm `straight-use-package` with pre-built packages does not trigger network calls
- [x] 2.2 Test that daemon starts successfully with packages on load-path
- [x] 2.3 Verify `(require ...)` works for activated packages

## 3. Update specification documentation

- [x] 3.1 Confirm delta spec at `openspec/changes/allow-straight-use-package-in-init/specs/emacs-package-provisioning/spec.md` reflects the runtime activation behavior
